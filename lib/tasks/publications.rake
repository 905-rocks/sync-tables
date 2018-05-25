namespace :publications do
  desc "同步公用表结构"
  task :import => :environment do
    pull_repo
    fix_columns
  end

  def fix_columns
    subscriptions.each do |sub|
      sub_tables(sub).each do |table|
        unless exist_table? table["table_name"]
          create_missing_table(table["table_name"])
        end

        table["columns"].each do |column|
          result =  compare_column(table["table_name"], column)
          case result[:action]
          when "not_exist"
            add_missing_column(table["table_name"], column)
          when "type_error"
            change_column_type(table["table_name"], column)
          else
          end
        end
      end
    end
  end

  def subscriptions
    @subs ||= ((execute "select subpublications from pg_subscription").to_a.map {|x| x["subpublications"].match(/{(.*)}/)[1]}).uniq
  end

  def pull_repo
    if File.exist? repo_dic
      system "cd #{repo_dic} && git pull"
    else
      system "cd #{parent_dic} && git clone #{repo_url}"
    end
  end

  def parent_dic
    Rails.root.to_s.match(/(.*)\/.*$/)[1]
  end

  def safe_create_dir(dir)
    unless File.exist? dir
      system "mkdir #{dir}"
    end
    dir
  end

  def repo_dic
    parent_dic + "/logical-replication-tables"
  end

  def sub_tables(file)
    JSON.parse(File.read "#{repo_dic}/publications/#{file}")
  end

  def compare_column(table, column)
    results = execute(
      "SELECT data_type, column_name FROM information_schema.COLUMNS WHERE TABLE_NAME = '#{table}'"
    ).to_a.find {|x| x["column_name"] == column["column_name"]}
    if results
      if results["data_type"] == column["data_type"]
        {}
      else
        {action: "type_error"}
      end
    else
      {action: "not_exist"}
    end
  end

  def create_missing_table(table)
    execute "CREATE TABLE #{table}()"
  end

  def add_missing_column(table, column)
    execute "ALTER TABLE #{table} ADD COLUMN \"#{column['column_name']}\" #{column['data_type']}"
    puts "add column #{table} #{column}"
  end

  def change_column_type(table, column)
    execute "ALTER TABLE #{table} ALTER COLUMN \"#{column['column_name']}\" type #{column['data_type']} using #{column['column_name']}::#{column['data_type']}"
    puts "change column #{table} #{column}"
  end

  def execute(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

  def exist_table?(table)
    ActiveRecord::Base.connection.tables.include?(table)
  end
end
