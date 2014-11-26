require File.expand_path(File.join(File.dirname(__FILE__), '..', 'mysql'))
Puppet::Type.type(:mysql_user).provide(:mysql, :parent => Puppet::Provider::Mysql) do

  desc 'manage users for a mysql database.'

  # Build a property_hash containing all the discovered information about MySQL
  # users.
  def self.instances
    users = mysql([defaults_file, '-NBe',
      "SELECT CONCAT(User, '@',Host) AS User FROM mysql.user"].compact).split("\n")
    # To reduce the number of calls to MySQL we collect all the properties in
    # one big swoop.
    users.collect do |name|
      query = "SELECT MAX_USER_CONNECTIONS, MAX_CONNECTIONS, MAX_QUESTIONS, MAX_UPDATES, PASSWORD FROM mysql.user WHERE CONCAT(user, '@', host) = '#{name}'"
      @max_user_connections, @max_connections_per_hour, @max_queries_per_hour,
      @max_updates_per_hour, @password = mysql([defaults_file, "-NBe", query].compact).split(/\s/)

      new(:name                     => name,
          :ensure                   => :present,
          :password_hash            => @password,
          :max_user_connections     => @max_user_connections,
          :max_connections_per_hour => @max_connections_per_hour,
          :max_queries_per_hour     => @max_queries_per_hour,
          :max_updates_per_hour     => @max_updates_per_hour
         )
    end
  end

  # We iterate over each mysql_user entry in the catalog and compare it against
  # the contents of the property_hash generated by self.instances
  def self.prefetch(resources)
    users = instances
    resources.keys.each do |name|
      if provider = users.find { |user| user.name == name }
        resources[name].provider = provider
      end
    end
  end

  def create
    merged_name             = @resource[:name].sub('@', "'@'")
    password_hash            = @resource.value(:password_hash)
    max_user_connections     = @resource.value(:max_user_connections) || 0
    max_connections_per_hour = @resource.value(:max_connections_per_hour) || 0
    max_queries_per_hour     = @resource.value(:max_queries_per_hour) || 0
    max_updates_per_hour     = @resource.value(:max_updates_per_hour) || 0

    mysql([defaults_file, '-e', "GRANT USAGE ON *.* TO '#{merged_name}' IDENTIFIED BY PASSWORD '#{password_hash}' WITH MAX_USER_CONNECTIONS #{max_user_connections} MAX_CONNECTIONS_PER_HOUR #{max_connections_per_hour} MAX_QUERIES_PER_HOUR #{max_queries_per_hour} MAX_UPDATES_PER_HOUR #{max_updates_per_hour}"].compact)

    @property_hash[:ensure] = :present
    @property_hash[:password_hash] = password_hash
    @property_hash[:max_user_connections] = max_user_connections
    @property_hash[:max_connections_per_hour] = max_connections_per_hour
    @property_hash[:max_queries_per_hour] = max_queries_per_hour
    @property_hash[:max_updates_per_hour] = max_updates_per_hour

    exists? ? (return true) : (return false)
  end

  def destroy
    merged_name = @resource[:name].sub('@', "'@'")
    mysql([defaults_file, '-e', "DROP USER '#{merged_name}'"].compact)

    @property_hash.clear
    exists? ? (return false) : (return true)
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

  ##
  ## MySQL user properties
  ##

  # Generates method for all properties of the property_hash
  mk_resource_methods

  def password_hash=(string)
    merged_name = self.class.cmd_user(@resource[:name])
    mysql([defaults_file, '-e', "SET PASSWORD FOR #{merged_name} = '#{string}'"].compact)

    password_hash == string ? (return true) : (return false)
  end

  def max_user_connections=(int)
    merged_name = self.class.cmd_user(@resource[:name])
    mysql([defaults_file, '-e', "GRANT USAGE ON *.* TO #{merged_name} WITH MAX_USER_CONNECTIONS #{int}"].compact).chomp

    max_user_connections == int ? (return true) : (return false)
  end

  def max_connections_per_hour=(int)
    merged_name = self.class.cmd_user(@resource[:name])
    mysql([defaults_file, '-e', "GRANT USAGE ON *.* TO #{merged_name} WITH MAX_CONNECTIONS_PER_HOUR #{int}"].compact).chomp

    max_connections_per_hour == int ? (return true) : (return false)
  end

  def max_queries_per_hour=(int)
    merged_name = self.class.cmd_user(@resource[:name])
    mysql([defaults_file, '-e', "GRANT USAGE ON *.* TO #{merged_name} WITH MAX_QUERIES_PER_HOUR #{int}"].compact).chomp

    max_queries_per_hour == int ? (return true) : (return false)
  end

  def max_updates_per_hour=(int)
    merged_name = self.class.cmd_user(@resource[:name])
    mysql([defaults_file, '-e', "GRANT USAGE ON *.* TO #{merged_name} WITH MAX_UPDATES_PER_HOUR #{int}"].compact).chomp

    max_updates_per_hour == int ? (return true) : (return false)
  end

end
