class apache::command {
    $cmd = $osfamily ? {
      'redhat' => 'yum',
      'debian' => 'apt',
       default => 'apt-get',
       }
    exec { 'apt-get update':
      command => '/usr/bin/$cmd update'
     }
}
