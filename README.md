leercat
=======

leercat is currently just a twitter app written in ruby. it uses the twitter gem and also as of 8/5/14 it uses the whatlanguage gem.

leercat is designed to be ran on your own account as an application. it can perform various functions, however due to the twitter ToS, misusing leercat will get your account locked. as of right now, there are various procedures that i have written but have not defined a clear path of control for the client. there is a lot of work to be done.

leercat can currently

- find and (un)follow gain tweet spammers
- unfollow all unfollowers
- unfollow people not tweeting in your native language

setup
=====

`gem install twitter`
`gem install whatlanguage`

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
