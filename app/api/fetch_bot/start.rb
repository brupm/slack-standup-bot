module FetchBot
  class Start < Grape::API
    get :start do
      @settings = Setting.first
      client = Slack::RealTime::Client.new

      puts "client #{client}"

      client.on :hello do
        group   = client.groups.detect { |c| c['name'] == @settings.name }
        channel = Channel.where(name: group['name'], slack_id: group['id']).first_or_initialize

        puts "group #{group}"
        puts "channel #{channel}"

        # TODO we need to move all this logic to a separated class
        ActiveRecord::Base.transaction do
          channel.save!

          users  = client.users
          puts "users #{users}"
          bot_id = users.find { |what| what['name'] == @settings.bot_name }['id']

          puts "bot_id #{bot_id}"

          @settings.update_attributes(bot_id: bot_id)

          group['members'].each do |member|
            slack_user = users.select { |u| u['id'] == member }.first

            puts "slack_user #{slack_user}"

            user = User.where(slack_id: slack_user['id']).first_or_initialize

            puts "user #{user}"

            user.full_name= slack_user['profile']['real_name_normalized']
            user.nickname= slack_user['name']
            user.avatar_url= slack_user['profile']['image_72']
            user.bot= (slack_user['id'] == @settings.bot_id)

            puts "user.save! #{user.save!}"

            user.save!

            channel.users << user
          end
        end

        if channel.complete?
          client.message channel: group['id'], text: 'Today\'s standup is already completed.'
          client.stop!
        else
          client.message channel: group['id'], text: 'Welcome to standup! Type "-Start" to get started.'
        end
      end

      client.on :message do |data|
        IncomingMessage.new(data, client).execute
      end

      client.start!
    end

  end
end
