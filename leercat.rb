#!/usr/bin/ruby

require 'Twitter'
require 'whatlanguage'
load 'config.rb'

MAX_ATTEMPTS = 1000

class Leercat
	def initialize(config)
		@client = Twitter::REST::Client.new(config)
		@stream = Twitter::Streaming::Client.new(config)
		@whatlanguage = WhatLanguage.new(:all)
		@do_not_remove_list = []
		@interesting_subjects = ['social media marketing', 'gain tweet', 'streamer', 'followers', 'anime', 'dancing', 'shuffling', 'brostep', 'jpop', 'kpop', 'metal', 'dubstep', 'dnb', 'trap', 'house', 'electro-house', 'hardcore', 'post-hardcore', 'rock', 'minecraft', 'league of legends', 'gamer']
		@gain_tweet_words = ['#جــدة','#ＲＥＴＷＥＥＴ','#TFB_Cats','RT2GAIN','FOLLOWBACK','#FOLLOW','followback','#MGWV','#AnotherFollowTrain','FOLLOWTRICK','#TEAMFOLLOWBACK','#TEAMMZBNIKKI']
	end

	def get_gain_tweet_words
		return @gain_tweet_words
	end

	def get_interesting_subjects
		return @interesting_subjects
	end

	def perform_rate_limited_action
		begin
			yield
		rescue Twitter::Error::NotFound => error
			puts "Twitter could not find the object you are requesting to use."
		rescue Twitter::Error::ServiceUnavailable => error
			puts "Twitter API is unavailable at this moment. We will retry in a few seconds."
			sleep 5
			retry
		rescue Twitter::Error::TooManyRequests => error
			puts "We hit the rate limit. Sleeping for #{error.rate_limit.reset_in} seconds."
			sleep error.rate_limit.reset_in
			retry
		end
	end

	def create_following_list()
		perform_rate_limited_action {
			@following_ids = @client.friend_ids
		}
		return @following_ids
	end

	def get_list_members(list_owner, list_name)
		list_members = []
		perform_rate_limited_action {
			@client.list_members(list_owner, list_name).each do |user| 
				if !list_members.include?(user.id)
					list_members.push(user.id)
				end
			end
		}
		return list_members	
	end

	def create_unfollower_list()
		unfollow_ids = []
		@following_ids.each_slice(100) do |section|
			perform_rate_limited_action {
				@client.friendships(section).each do |user|
					follows_me  = user.connections.include? 'followed_by'
					if !follows_me and !@do_not_remove_list.include?(user.id) then
						puts "#{user.name} (@#{user.screen_name}) does not follow me."
						unfollow_ids.push(user.id)
					end
				end
			}
		end
		return unfollow_ids
	end

	def bulk_unfollow(unfollow_ids)
		unfollow_ids = unfollow_ids - @do_not_remove_list
		unfollow_ids.each_slice(100) do |section|
			perform_rate_limited_action {
				@client.unfollow(section)
				puts "Bulk unfollowed."
			}
		end
	end

	def bulk_follow(follow_ids)
		follow_ids.each do |id|
			perform_rate_limited_action {
				@client.follow(id)
				puts "Followed user."
			}
		end
		puts "Bulk followed."
	end

	def bulk_add_to_list(list_owner,list_name,user_ids)
		user_ids.each_slice(100) do |section|
			perform_rate_limited_action {
				@client.add_list_members(list_owner,list_name,section)
			}
		end
	end

	def search_users(search_term)
		total_users = []
		perform_rate_limited_action {
			found_users = @client.user_search(search_term, { :count => 20, :page => 0 })
		}
		return found_users
	end 

	def find_users_tweeting(search_terms, max_list_size)
		list_to_follow = []
		@stream.filter(:track => search_terms.join(",")) do |object|
			if !list_to_follow.include?(object.user.id)
				list_to_follow.push(object.user.id)
			end

			if list_to_follow.length >= max_list_size
				return list_to_follow
			end
		end
	end

	def is_spam_tweet(text)
		if @gain_tweet_words.any? { |word| text.include?(word) }
			return true
		end

		return false
	end

	# this function is pretty bad for now.
	def is_foreign_tweet(text)
		language = @whatlanguage.language(text)
		# puts "#{text} is thought to be #{language}"
		if language != "english"
			return true
		end

		return false
	end

	def find_people_to_unfollow(count=100, max_read=250)
		unfollow_list = []
		read = 0
		@stream.user do |object|
			case object
			when Twitter::Tweet
				read += 1
				add_to_list = false
				if is_spam_tweet(object.text) && !@do_not_remove_list.include?(object.user.id) && !unfollow_list.include?(object.user.id)
					unfollow_list.push(object.user.id)
					puts "Putting #{object.user.id} on the spammer list."
					puts "Unfollow list count: #{unfollow_list.length}"
				end
			end
			puts "Total Read: #{read}"
			if unfollow_list.length >= count || read >= max_read
				return unfollow_list
			end
		end		
	end

	def get_trending_list()
		puts @client.trends()
	end

	def begin()
		@stream.user do |object|
			case object
			when Twitter::Tweet
			end
		end
	end

	def set_do_not_remove_list(list)
		@do_not_remove_list = list
	end

end

leer = Leercat.new($config)
search_terms = leer.get_interesting_subjects.map { |word| "#{word} followback" } 

search_terms.each do |term|
	leer.bulk_add_to_list('sgorman07','Followback', leer.search_users(term))
end
#leer.bulk_add_to_list('sgorman07','FIFO-Gains', )
#leer.set_do_not_remove_list(leer.get_list_members("sgorman07","CAPTCHA"))

#leer.create_following_list()
#unfollow_ids = leer.create_unfollower_list();
#leer.bulk_unfollow(unfollow_ids)




#while true do
#	leer.bulk_unfollow(leer.find_people_to_unfollow())
#end
=begin
leer.create_following_list()
followed_count = 0
while true do
	if followed_count >= 200
		leer.create_following_list()
		unfollow_ids = leer.create_unfollower_list();
		leer.bulk_unfollow(unfollow_ids)
		followed_count = 0
	end
	follow_these_ids = leer.find_people_to_follow(15)
	leer.bulk_follow(follow_these_ids)
	followed_count += 15
end
=end

#leer.bulk_unfollow(unfollow_ids)

