class usercreate {

  user { 'ganeshhp':
    ensure           => 'present',
    gid              => '1000',
    home             => '/home/ganeshhp',
    password         => '$1$k7LuBXte$Z28nFzLRxAqzl0/53fkl50',
    password_max_age => '99999',
    password_min_age => '0',
    shell            => '/bin/bash',
    uid              => '2010',
    }

}

