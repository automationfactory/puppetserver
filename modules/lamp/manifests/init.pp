# Class: lamp
# ===========================
#
# Full description of class lamp here.
#
# Parameters
# ----------
#
# Document parameters here.
#
# * `sample parameter`
# Explanation of what this parameter affects and what it defaults to.
# e.g. "Specify one or more upstream ntp servers as an array."
#
# Variables
# ----------
#
# Here you should define a list of variables that this module would require.
#
# * `sample variable`
#  Explanation of how this variable affects the function of this class and if
#  it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#  External Node Classifier as a comma separated list of hostnames." (Note,
#  global variables should be avoided in favor of class parameters as
#  of Puppet 2.6.)
#
# Examples
# --------
#
# @example
#    class { 'lamp':
#      servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#    }
#
# Authors
# -------
#
# Author Name <author@domain.com>
#
# Copyright
# ---------
#
# Copyright 2018 Your name here, unless otherwise noted.
#
class lamp {

	# execute 'apt-get update'
	exec { 'apt-update':                    # exec resource named 'apt-update'
	  command => '/usr/bin/apt-get update'  # command this resource will run
	}

	# install apache2 package
	package { 'apache2':
	  require => Exec['apt-update'],        # require 'apt-update' before installing
	  ensure => installed,
	}

	# ensure apache2 service is running
	service { 'apache2':
	  ensure => running,
	}

	# install mysql-server package
	package { 'mysql-server':
	  require => Exec['apt-update'],        # require 'apt-update' before installing
	  ensure => installed,
	}

	# ensure mysql service is running
	service { 'mysql':
	  ensure => running,
	}

	# install php5 package
	package { 'php5':
	  require => Exec['apt-update'],        # require 'apt-update' before installing
	  ensure => installed,
	}

	# ensure info.php file exists
	file { '/var/www/html/info.php':
	  ensure => file,
	  content => '<?php  phpinfo(); ?>',    # phpinfo code
	  require => Package['apache2'],        # require 'apache2' package before creating
	} 

}
