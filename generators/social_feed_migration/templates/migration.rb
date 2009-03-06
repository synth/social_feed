class AddSocialFeed < ActiveRecord::Migration
  def self.up
    add_column :users, :feed_event_subscriptions, :text
    add_column :users, :email_subscriptions, :text
    add_column :users, :enabled_feed_events, :text
    
    create_table :feed_events do |t|
      t.column :type, :string
      t.column :user_id, :integer
      t.column :source_id, :integer
      t.column :source_type, :string
      t.column :hint_body, :text
      t.column :details, :text
      t.column :summarized_by, :integer
      t.column :summary_count, :integer
      t.timestamps
    end
    
  end

  def self.down
    remove_column :users, :feed_event_subscriptions
    remove_column :users, :email_subscriptions
    remove_column :users, :enabled_feed_events
    
    drop_table :feed_events
  end
end
