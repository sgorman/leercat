#!/usr/bin/ruby

require 'Twitter'
require 'whatlanguage'
require 'pg'

load 'config.rb'

MAX_ATTEMPTS = 1000

class Leercat
	def initialize(config)
		@client = Twitter::REST::Client.new(config)
		@stream = Twitter::Streaming::Client.new(config)
		@whatlanguage = WhatLanguage.new(:all)
		@do_not_remove_list = []
		@interesting_subjects = ['anime', 'otaku', 'attack on titan', 'flcl', 'social media marketing', 'gain tweet', 'streamer', 'followers', 'anime', 'dancing', 'shuffling', 'brostep', 'jpop', 'kpop', 'metal', 'dubstep', 'dnb', 'trap', 'house', 'electro-house', 'hardcore', 'post-hardcore', 'rock', 'minecraft', 'league of legends', 'gamer']
		@gain_tweet_words = ['#جــدة','#ＲＥＴＷＥＥＴ','#TFB_Cats','RT2GAIN','FOLLOWBACK','#FOLLOW','followback','#MGWV','#AnotherFollowTrain','FOLLOWTRICK','#TEAMFOLLOWBACK','#TEAMMZBNIKKI']
		@database = PGconn.open(:dbname => "leercat")
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

	def update_users(user_ids)
		puts user_ids.to_s
		follows_me_table = []
		user_ids.each_slice(100) do |section|
			perform_rate_limited_action {
				@client.friendships(section).each do |user|
					puts user.connections
					follows_me_table[user.id]  = user.connections.include? 'followed_by'
				end
			}
			perform_rate_limited_action {
				@client.users(section).each do |user|
					twitter_id = user.id
					name = user.name
					screen_name = user.screen_name
					tweet_count = user.statuses_count
					followers = user.followers_count
					following = user.friends_count
					ratio = following.to_f / followers.to_f
					last_activity = user.status.created_at.to_i
					follows_me = follows_me_table[twitter_id]
					puts follows_me
					puts "Updating @#{screen_name}..."
					@database.exec("BEGIN")
					result = @database.exec("SELECT * FROM lc_user_statistics WHERE twitter_id = #{twitter_id} FOR UPDATE")
					if result.ntuples >= 1 then
						@database.exec("UPDATE lc_user_statistics SET last_check = CURRENT_TIMESTAMP, follows_me = #{follows_me}, last_activity = to_timestamp('#{last_activity}'), screen_name = '#{screen_name}', following = #{following}, followers = #{followers}, ratio = #{ratio} WHERE twitter_id = #{twitter_id}")
					else
						@database.exec("INSERT INTO lc_user_statistics (twitter_id, last_check, follows_me, last_activity, screen_name, following, followers, ratio) VALUES(#{twitter_id}, CURRENT_TIMESTAMP, #{follows_me}, to_timestamp('#{last_activity}'), '#{screen_name}', #{following}, #{followers}, #{ratio})")
					end
					@database.exec("COMMIT")
				end
			}
		end
	end


	# look for users who have not been updated in the last 24 hours.
	def find_users_who_need_update()
		needs_updates = []
		@database.exec("BEGIN")
		result = @database.exec("SELECT twitter_id FROM lc_user_statistics WHERE age(last_check) is NULL OR age(last_check) < '2 hours'::interval ")
		result.each_row do |row|
			#puts row
			needs_updates.push(row[0].to_i)
		end
		@database.exec("COMMIT")

		return needs_updates
	end

	def find_users_who_dont_follow()
		@database.exec("BEGIN")
		result = @database.exec("SELECT twitter_id FROM lc_user_statistics WHERE follows_me is FALSE")
		result.each_row do |row|
			puts row
		end
		@database.exec("COMMIT")
	end

	#def lookup_users(user_ids)
		#@database.exec("")
	#end

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
				if !list_members.include?(user.id) then
					list_members.push(user.id)
				end
			end
		}
		return list_members	
	end

	def create_unfollower_list()
		unfollow_ids = []
		perform_rate_limited_action {
			@following_ids.each_slice(100) do |section|
				#update_users(section)
				#puts section.inspect
				@client.friendships(section).each do |user|
					#puts user.inspect
					follows_me  = user.connections.include? 'followed_by'
					if !follows_me and !@do_not_remove_list.include?(user.id) then
						puts "#{user.name} (@#{user.screen_name}) does not follow me."
						unfollow_ids.push(user)
					end
				end
			end
		}
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
			if !list_to_follow.include?(object.user.id) then
				list_to_follow.push(object.user.id)
			end

			if list_to_follow.length >= max_list_size
				return list_to_follow
			end
		end
	end

	def is_spam_tweet(text)
		if @gain_tweet_words.any? { |word| text.include?(word) } then
			return true
		end

		return false
	end

	# this function is pretty bad for now.
	def is_foreign_tweet(text)
		language = @whatlanguage.language(text)
		# puts "#{text} is thought to be #{language}"
		if language != "english" then
			return true
		end

		return false
	end
=begin
	def find_people_to_unfollow(count=100, max_read=250)
		unfollow_list = []
		read = 0
		@stream.user do |object|
			case object
			when Twitter::Tweet
				read += 1
				add_to_list = false
				if is_spam_tweet(object.text) && !@do_not_remove_list.include?(object.user.id) && !unfollow_list.include?(object.user.id) then
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
=end

	#def get_trending_list()
	#	puts @client.trends()
	#end

	#def begin()
	#	@stream.user do |object|
	#		case object
	#		when Twitter::Tweet
	#		end
	#	end
	#end

	def set_do_not_remove_list(list)
		@do_not_remove_list = list
	end

end

=begin

Finding good follower in Twitter alogrithm
------------------------------------------

Check followers/following ratio.
Check latest activity.
Look for keywords when searching for users.
Check for spam or gain tweets. (Optional)
Check for links in bio. (Optional)

Database Outline
-----------------

Store users into the database and record data about each user when possible.

twitter_id (long), last_activity (date), following (int), followers (int), 
follower_ratio (double), spammer (bool), full_bio (bool), following_score (double)

=end
	
leer = Leercat.new($config)
#leer.set_do_not_remove_list(leer.get_list_members("sgorman07","CAPTCHA"))

#leer.create_following_list()
#unfollow_ids = leer.create_unfollower_list();
#leer.bulk_unfollow(unfollow_ids)
leer.update_users(leer.find_users_who_need_update())
leer.find_users_who_dont_follow()
#leer.bulk_unfollow(unfollow_ids)
