class ntp {

  $appname = $osfamily ? {
    'redhat' => 'ntp',
    'debian' => 'ntp',
     default => 'ntp',
     }

  $servicename = $osfamily ? {
   'redhat' => 'ntpd',
   'debian' => 'ntp',
    default => 'ntp',
    }

    package { $appname:
       ensure => 'installed',
     }

    service { $servicename:
       ensure => 'running',
       enable => true,
     }

}