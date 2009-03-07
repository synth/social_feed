module SocialFeed
  module UserExtension
    
    def self.included(base)
      base.class_eval do
        serialize :feed_event_subscriptions
        serialize :email_subscriptions
        serialize :enabled_feed_events
        
        has_many :feed_events, :dependent => :destroy, :order => "id DESC"
        has_many :feed_events_as_source, :dependent => :destroy, :as => :source, :class_name => 'FeedEvent'
        has_many :summarized_feed_events, :class_name =>"FeedEvent", :dependent => :destroy, :conditions => "summarized_by_id IS NULL"

      end
      
    end
    
    def subscribe_to_feed_event(event_class) 
      self.feed_event_subscriptions ||= []
      self.feed_event_subscriptions |= [event_class.to_s]
      if(u = User.find(:first, :conditions => {:id => SocialFeed::Conf.system_feed_id}))
        self.copy_historical_feed_events(u, event_class)
      end
    end
    
    def subscribed_to_feed_event?(event_class)
      self.feed_event_subscriptions.if_not_nil?{|s| s.include?(event_class.to_s)}
    end
    
    def unsubscribe_from_feed_event(event_class)
      self.feed_event_subscriptions_will_change!
      self.feed_event_subscriptions.delete event_class.to_s
      FeedEvent.delete_all :user_id => self.id, :type => event_class.to_s
    end
    
    def subscribe_to_email(event_class) 
      self.email_subscriptions ||= []
      self.email_subscriptions |= [event_class.to_s]
    end
    
    def subscribed_to_email?(event_class)
      self.email_subscriptions.if_not_nil?{|s| s.include?(event_class.to_s)}
    end
    
    def unsubscribe_from_email(event_class)
      self.email_subscriptions_will_change!
      self.email_subscriptions.delete event_class.to_s
    end
    
    def enable_feed_event(event_class)
      self.enabled_feed_events ||= []
      self.enabled_feed_events |= [event_class.to_s]
    end
    
    def disable_feed_event(event_class)
      self.enabled_feed_events_will_change!
      self.enabled_feed_events.delete event_class.to_s
    end
    
    def feed_event_enabled?(event_class)
      self.enabled_feed_events.if_not_nil?{|e| e.include? event_class.to_s}
    end
    
    def copy_historical_feed_events(user, event_class)
      event_class = event_class.kind_of?(Class) ? event_class : event_class.constantize
      events = user.feed_events.find :all, :conditions=>{:type => event_class.to_s}, :limit => SocialFeed::Conf.historical_feed_count
      events.each do |e|
        e = event_class.create :user => self, :source => e.source, :details => e.details, :forbid_email => true, :created_at => e.created_at, :updated_at => e.updated_at
      end
    end
  end
end