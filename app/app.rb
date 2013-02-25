class MturkThumbnails < Padrino::Application
  use ActiveRecord::ConnectionAdapters::ConnectionManagement
  register Padrino::Rendering
  register Padrino::Helpers
  register Padrino::Assets

  enable :sessions
end
