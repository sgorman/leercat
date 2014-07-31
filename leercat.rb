require 'Twitter'

config = {
  :consumer_key        => "***REMOVED***",
  :consumer_secret     => "***REMOVED***",
  :access_token        => "***REMOVED***",
  :access_token_secret => "***REMOVED***",
}

client = Twitter::REST::Client.new(config)

MAX_ATTEMPTS = 10
num_attempts = 0

begin
	num_attempts += 1
	following_ids = client.friend_ids
	unfollow_ids = []
	following_ids.each_slice(100) do |section|
		begin
			client.friendships(section).each do |user|
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

unfollow_ids.each_slice(100) do |section|
	begin
		num_attempts += 1
		client.unfollow(section)
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