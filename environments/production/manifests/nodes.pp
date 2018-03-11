class testfile {
    file { 'info.txt':
       ensure => 'present',
       path => '/root/info.txt',
       content => inline_template("Created by Puppet at <%= Time.now %>\n"),
     }
   }

#class tools {
#     $tools = ['ntp']
#     package { $tools:
#     ensure => 'installed',
#   }
#     service { $tools:
#     ensure => 'running',
#     enable => true,
#   }
#}

#node 'puppetnode' {
#      class { 'sample': }
#      class { 'tools': }
#      class { 'mysite': }
#      class { 'apache': }
#}

node 'node2.tikona.net' {
    class { 'apache': }
    class  { 'ntp': }
}

node 'node1.tikona.net' {
   class { 'apache': }
   class { 'ntp': }
}
