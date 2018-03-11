class mysite {

  $phpmysql = $osfamily ? {
    'redhat' => 'php-mysql',
    'debian' => 'php5-mysql',
     default => 'php-mysql',
   }
  package { $phpmysql:
    ensure => 'present',
   }
  if $osfamily == 'redhat' {
    package { 'php-xml':
    ensure => 'present',
    }
  }
  class { '::apache':
    docroot    => '/var/www/html',
    mpm_module => 'prefork',
    subscribe  => Package[$phpmysql],
  }
  class { '::apache::mod::php':}
   vcsrepo { '/var/www/html/':
     ensure => 'present',
     provider => 'git',
     source => "https://github.com/ganeshhp/website.git",
     revision => '1.0.1',
   }
}
