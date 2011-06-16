# example
# converter = Mysql::Converter.new("dbname", "user", "password", "host")
# converter.convert!("innodb")

module Mysql
  class Converter
    attr_accessor :database, :user, :password, :host, :table_names
    
    def initialize(database, user, password = nil, host = nil)
      @database, @user, @password, @host = database, user, password, host
      @cmd = "/usr/local/mysql/bin/mysql -u#{user} #{"-p" + password if password} #{"-h " + host if host} -e \"{{cmd}};\" --database {{database}} --skip-column-names"
    end
    
    def command(sql, database = nil)
      command = @cmd.gsub "{{database}}", database ? database : @database
      command = command.gsub("{{cmd}}", sql)
      `#{command}`
    end
    
    def table_names
      @table_names ||= command("select table_name from tables where table_schema = '#{@database}'", "information_schema").split("\n")
    end
  
    def convert!(engine = "innodb")
      table_names.each do |table_name|
        send("convert_to_#{engine}", table_name)
      end
    end
    
    def convert_to_innodb(table_name)
      command("CREATE TABLE #{table_name}_innodb LIKE #{table_name}")
      command("ALTER TABLE #{table_name}_innodb ENGINE='INNODB'")
      command("INSERT INTO #{table_name}_innodb SELECT * FROM #{table_name}")
      command("ALTER TABLE #{table_name} RENAME #{table_name}_myisam")
      command("ALTER TABLE #{table_name}_innodb RENAME #{table_name}")
      command("DROP TABLE #{table_name}_myisam")
    end
  end
end
