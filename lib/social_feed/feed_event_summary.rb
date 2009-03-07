module SocialFeed
  module FeedEventSummary
    def self.included(base)
    
      #we want to add some behavior to the base class too, but only do it once
      FeedEvent.send(:include, FeedEventExtension) unless FeedEvent.ancestors.include?(FeedEventExtension)
    
      base.class_eval do
        after_save :summarize, :if => Proc.new{|record| record.summary_count.nil?}
        # before_validation :update_previous_event
        # before_update :clear_hint_body
        # validate :previous_event_exists
      end
    end
  
    module FeedEventExtension
      def self.included(base)
        base.class_eval do
          belongs_to :summarized_by, :class_name => self.to_s
          has_many :events_summarized, :class_name => self.to_s, :foreign_key => "summarized_by_id"
        end
        base.extend(ClassMethods)
      end

      def summary?
        !self.summary_count.nil?
      end

      module ClassMethods
        #TODO: Ideally, we should merge conditions here, but I'm not quite sure how
        #to do it without potentially breaking the original find, so just filtering
        #after the fact for now
        def find_with_summarize(*args)
          set = self.find(*args)
          set.reject{|r| r.summarized_by}
        end
      end
    end
  
    private

    def summarize
      @previous_events = user.feed_events.find :all, :conditions => ['type = ? AND id <> ? AND summary_count IS NULL', self.class.to_s, self.id]
      
      #if we can summarize
      unless(@previous_events.empty?)

        #if the first duplicate(2nd time)
        if(@previous_events.length == 1)
          
          #create the summary
          summary_event =  self.class.create :user => self.user, :forbid_email => true, :source => self.source, :summary_count => @previous_events.length + 1

          #link both events to summary
          @previous_events << self
          @previous_event_ids = @previous_events.collect{|e| e.id}.join(', ')
          FeedEvent.update_all "summarized_by_id = #{summary_event.id}", "id IN (#{@previous_event_ids})"

        #otherwise, we have existing summary
        else
          #update summary count
          summary_event = @previous_events.first.summarized_by
          summary_event.increment! :summary_count
          
          #link new event to summary
          FeedEvent.update_all "summarized_by_id = #{summary_event.id}", "id = #{self.id}"
        end

      end
    end

    def clear_hint_body
      self.hint_body = nil if action_count_changed?
    end
  end
end