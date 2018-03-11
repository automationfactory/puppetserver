# Class: apache
# ===========================
# Full description of class apache here.
#
# Parameters
# ----------
# Document parameters here.
#
# * `sample parameter`
# Explanation of what this parameter affects and what it defaults to.
# e.g. "Specify one or more upstream ntp servers as an array."
#
# Variables
# ----------
# Here you should define a list of variables that this module would require.
#
# Authors
# -------
#
# Author Name <author@domain.com>
#
# Copyright
# ---------
# Copyright 2018 Your name here, unless otherwise noted.

class apache {
    $webserver = $osfamily ? {
      'redhat' => 'httpd',
      'debian' => 'apache2',
       default => 'apache2',
       }
   package {$webserver:
       ensure => 'present',
       }
   service { $webserver:
       ensure => 'running',
       enable => true,
       }

   file { 'index.html':
       ensure  => 'present',
       path    => '/var/www/html/index.html',
       content => "<!doctype html>
                <title>Welcome Page</title>
                <style>
                body { text-align: center; padding: 150px; }
                h1 { font-size: 50px; }                   none
                  body { font: 20px Helvetica, sans-serif; color: #333; }
                  article { display: block; text-align: left; width: 650px; margin:$                  a { color: #dc8100; text-decoration: none; }
                  a:hover { color: #333; text-decoration: none; }
                </style>

                <article>
                <h2>Hello, Welcome to the training session on Puppet!</h2>
                 <div>
                     <p>Puppet is a very cool tool for configuration management.</p>                     <p>&mdash; Ganesh Palnitkar</p>

                 </div>
                </article>"
       }

  include 'apache::command'

 }
