module SocialFeed
  module SocialFeedHelper
    def feed_event_partial_name(event)
      "feed_events/"+event.class.name.underscore.sub(/event$/, 'hint')
    end
  end
end