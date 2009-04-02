module SocialFeed
  module ActiveRecordExtension
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.send(:extend, ClassMethods)
    end
    
    module InstanceMethods
      
    end
    
    module ClassMethods
      #You can pick and choose which callbacks you want to monitor by naming an event to that callback
      #eg, to monitor additions, specify 
      #      :added_event => ProjectAddedEvent
      #      :updated_event => ProjectUpdatedEvent
      #      :deleted_event => ProjectDeletedEvent
      def acts_as_social_feed(opts={})
        
        use_added_event = opts[:added_event]
        use_updated_event = opts[:updated_event]
        use_deleted_event = opts[:deleted_event]
        
        raise ArgumentError, "Invalid event to handle the additions" if use_added_event and !opts[:added_event].ancestors.include?(FeedEvent)
        raise ArgumentError, "Invalid event to handle the updates" if use_updated_event and !opts[:updated_event].ancestors.include?(FeedEvent)
        raise ArgumentError, "Invalid event to handle the deletions" if use_deleted_event and !opts[:deleted_event].ancestors.include?(FeedEvent)
        
        wrap_for_add(use_added_event) if(use_added_event)
        
        wrap_for_update(use_updated_event) if(use_updated_event)

        wrap_for_delete(use_deleted_event) if(use_deleted_event)

      end

      private
      def wrap_for_add(event_klass)
        class_inheritable_accessor :added_event
        self.added_event = event_klass
        after_create :update_feed_from_addition
        class_eval{
          def update_feed_from_addition
            User.find(:all).each do |u|
              self.class.added_event.create :user => u, :source => self
            end
          end            
        }        
      end
      
      def wrap_for_update(event_klass)
        attr_accessor :stashed_changes

        class_inheritable_accessor :updated_event
        self.updated_event = event_klass   
        before_update :stash_changes
        after_update :update_feed_from_update, :unless => Proc.new{|u| u.stashed_changes.reject{|k,v| k == "feed_event_subscriptions"}.empty?} 
        class_eval{
         def stash_changes
            self.stashed_changes = self.changes
            self.stashed_changes.delete("updated_at")#we don't want to count this as an attribute that was changed
            self.stashed_changes
          end
          

          def update_feed_from_update
            User.find(:all).each do |u|
              self.class.updated_event.create :user => u, :source => self, :details => stashed_changes
            end
          end          
        }
      end
      
      def wrap_for_delete(event_klass)
        class_inheritable_accessor :deleted_event
        self.deleted_event = event_klass
        before_destroy :update_feed_from_deletion
        class_eval{
          def update_feed_from_deletion
            User.find(:all).each do |u|
              self.class.deleted_event.create :user => u, :source => self
            end
          end          
        }
      end
    end
    
  end
end