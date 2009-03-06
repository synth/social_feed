class FeedEvent < ActiveRecord::Base
  def before_validation_on_create
    send_email
  end
  
  belongs_to :source, :polymorphic => true
  validates_presence_of :user_id #receiver
  validate :source_user_has_event_enabled
  validate :user_has_subscribed_to_event
  
  @@event_types = []
  
  belongs_to :user

  serialize :details
  
  #allow creaters of events to dynamically suppress emails even if there are email subscribers
  #and/or all other conditions are met
  attr_accessor :forbid_email
  
  #This method allows you to specify a class to follow the changes
  #It stashes the changes in a before filter and you can optionally
  #specify an after filter on the followed class as well.
  #
  #The idea is that this logic isn't core to the source class and you
  #may want to have lots of logic for displaying the feed depending
  #on what has changed
  #
  #This is certainly clunky, but until a better way comes around.  I 
  #considered using observers but it seemed a whole lot heavier for not
  #that much gain.  The event classes are fairly empty and seem like an
  #appropriate place to put logic concerning...umm...the event.
  def self.follows(klass, opts={})
    klass = klass.to_s.capitalize.constantize
    event = self
    klass.class_eval{
      attr_accessor :stashed_changes
      @@followed_by = event
      before_save {|record| record.stashed_changes = record.changes}
      #I thought there might be a use for this, but not sure now...
      # after_save {|record| @@followed_by.send(opts[:with], record)} if opts[:with]
    }
  end
  
  def self.notify_subscribers(opts)
    User.find(:all).each do |u|
      UserUpdateEvent.create opts.merge(:user => u)
    end
  end
  
  def allowed_to_destroy?(_user_id)
    (user_id == _user_id)
  end
  
  def self.event_types
    load_subclasses if @@event_types.empty?
    @@event_types
  end
  
  def self.subscribable_feed_event_types
    event_types.reject{|type| type.user_cannot_subscribe_to_event?}
  end
  
  def self.enabable_feed_event_types
    event_types.select{|type| type.user_can_enable_event?}
  end
  
  def self.subscribe_description(desc = nil)
    @@subscribe_descriptions ||= {}
    @@subscribe_descriptions[name] = desc if desc
    @@subscribe_descriptions[name]
  end
  
  def self.privacy_description(desc = nil)
    @@privacy_descriptions ||= {}
    @@privacy_descriptions[name] = desc if desc
    @@privacy_descriptions[name]
  end

  def self.can_send_email?
    FeedEventMailer.send(:new).respond_to?(name.underscore[0..-7])
  end
  
  def self.user_cannot_subscribe_to_event?
    subscribe_description.blank?
  end
  
  def self.user_can_enable_event?
    privacy_description
  end
  
  private
  
  def source_disabled_event?
    self.class.user_can_enable_event? && source.respond_to?(:user) && source.user && !source.user.feed_event_enabled?(self.class)
  end

  def send_email
    FeedEventMailer.send "deliver_#{self.class.name.underscore[0..-7]}", self if self.class.can_send_email? && 
      (user.subscribed_to_email?(self.class) || self.class.user_cannot_subscribe_to_event?) && !user.try(:online?) && !source_disabled_event? && !self.forbid_email
  end
  
  def self.load_subclasses
    Dir[RAILS_ROOT+'/app/models/feed_events/*_event.rb'].each do |file|
      @@event_types << File.basename(file, '.rb').camelize.constantize
    end
  end
  
  def user_has_subscribed_to_event
    errors.add :user, "has not subscribed to event #{self.class}" unless user.if_not_nil?{|u| u.subscribed_to_feed_event?(self.class)} || 
      self.class.user_cannot_subscribe_to_event?
  end
  
  def source_user_has_event_enabled
    errors.add :source, "this event is disabled by the user of #{self.source.class}" if source_disabled_event?
  end
  
end
