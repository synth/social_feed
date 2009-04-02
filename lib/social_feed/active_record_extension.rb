module SocialFeed
  module ActiveRecordExtension
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.send(:extend, ClassMethods)
    end
    
    module InstanceMethods
      
    end
    
    module ClassMethods
      #monitors the updates of active records with an event that is named via options(:event => <RecordUpdateEvent>)
      def acts_as_social_feed(opts={})
        raise ArgumentError, "Invalid event to handle the updates" unless opts[:event].ancestors.include?(FeedEvent)
        
        #store the event that will handle the update
        class_inheritable_accessor :update_event
        self.update_event = opts[:event]
        
        attr_accessor :stashed_changes
        before_update :stash_changes
        after_update :update_feed, :unless => Proc.new{|u| u.stashed_changes.reject{|k,v| k == "feed_event_subscriptions"}.empty?} 
        
        class_eval{
          def stash_changes
            self.stashed_changes = self.changes
            self.stashed_changes.delete("updated_at")#we don't want to count this as an attribute that was changed
            self.stashed_changes
          end
          
          def update_feed
            User.find(:all).each do |u|
              self.class.update_event.create :user => u, :source => self, :details => stashed_changes
            end
          end
        }
      end
    end
    
  end
end