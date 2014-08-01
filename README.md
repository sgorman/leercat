leercat
=======

leercat is currently just a twitter script written in ruby. it uses the twitter gem.

what does it do?
================

running it will look through all your followers then unfollow anyone who does not follow you back.

setup
=====

`gem install twitter`

- edit the config.rb with your twitter app settings
- make sure you give your app full permissions
- run the program

usage
=====

`ruby leercat.rb`

additional stuff
================

run this command so you don't have to worry about adding your personal config file to the repo.

`git update-index --assume-unchanged config.rb`
