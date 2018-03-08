#import 'nodes.pp'
#$server = 'puppet.autoconf.com'


node default {
   package { 'apache2':
    ensure => installed,
   }
   service { 'apache2':
    ensure => running,
    enable => true,
   }
   file { 'index.html':
    ensure => 'present',
    path => '/var/www/html/index.html',
    content => '<html><h1>Hello World</h1></html>',
   }
   package {'mysql-server':
    ensure => absent,
   }
   service {'mysql':
    ensure => stopped,
    enable => false,
   }
}


