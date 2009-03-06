require 'object_extensions'

# configuration
require 'ostruct'
SocialFeed::Conf = OpenStruct.new YAML::load(File.read(RAILS_ROOT + '/config/social_feed.yml'))


ActionController::Base.helper(SocialFeed::SocialFeedHelper) 

ActionController::Routing::RouteSet::Mapper.send(:include, SocialFeed::Routing)

#make sure we load these files, 
#otherwise its possible to have activity on a 'followed' class before its had the specialized
#behavior injected in
FeedEvent.load_subclasses