#!/usr/bin/ruby

require 'Twitter'
load 'config.rb'

MAX_ATTEMPTS = 1000

class Leercat
	def initialize(config)
		@client = Twitter::REST::Client.new(config)
		@stream = Twitter::Streaming::Client.new(config)
	end

	def create_following_list()
		num_attempts = 0

		begin
			num_attempts += 1
			@following_ids = @client.friend_ids
		rescue Twitter::Error::TooManyRequests => error
			if num_attempts <= MAX_ATTEMPTS
				puts "We hit the rate limit sleeping for #{error.rate_limit.reset_in} seconds."
				sleep error.rate_limit.reset_in
				puts "Resuming operations."
				retry
			else
				raise
			end
		end

		return @following_ids
	end

	def create_unfollower_list()
		num_attempts = 0

		unfollow_ids = []
		@following_ids.each_slice(100) do |section|
			begin
				@client.friendships(section).each do |user|
					follows_me  = user.connections.include? 'followed_by'
					unless follows_me then
						puts "#{user.name} (@#{user.screen_name}) does not follow me."
						unfollow_ids.push(user)
					end
				end
			rescue Twitter::Error::TooManyRequests => error
				if num_attempts <= MAX_ATTEMPTS
					puts "We hit the rate limit sleeping for #{error.rate_limit.reset_in} seconds."
					sleep error.rate_limit.reset_in
					puts "Resuming operations."
					retry
				else
					raise
				end
			end
		end

		return unfollow_ids
	end

	def bulk_unfollow(unfollow_ids)
		num_attempts = 0
		unfollow_ids.each_slice(100) do |section|
			begin
				num_attempts += 1
				@client.unfollow(section)
				puts "Bulk unfollowed."
			rescue Twitter::Error::TooManyRequests => error
				if num_attempts <= MAX_ATTEMPTS
					puts "We hit the rate limit sleeping for #{error.rate_limit.reset_in} seconds."
					sleep error.rate_limit.reset_in
					puts "Resuming operations."
					retry
				else
					raise
				end
			end
		end
	end

	def bulk_follow(follow_ids)
		num_attempts = 0
		follow_ids.each do |id|
			begin
				@client.follow(id)
				puts "Followed user."
			rescue Twitter::Error::TooManyRequests => error
				puts "We hit the rate limit sleeping for #{error.rate_limit.reset_in} seconds."
				sleep error.rate_limit.reset_in
				puts "Resuming operations."
				retry
			end
		end
		puts "Bulk followed."
	end

	def find_people_to_follow(max_list_size)
		list_to_follow = []
		topics = ["follow4follow", "followback", "followme", "followtrick"]
		@stream.filter(:track => topics.join(",")) do |object|
			if !@following_ids.include?(object.user.id) && !list_to_follow.include?(object.user.id)
				list_to_follow.push(object.user.id)
			end

			if list_to_follow.length >= max_list_size
				return list_to_follow
			end
		end
	end

end

leer = Leercat.new($config)
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
