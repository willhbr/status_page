require "http"
require "log"
require "ecr"

require "./section"
require "./default_pages"

module StatusPage
end

class StatusPage::Handler
  include HTTP::Handler

  @@instance : Handler? = nil
  @sections = Array(Section).new

  def self.handler
    @@instance ||= new
  end

  private def initialize
  end

  def self.add_section(section)
    handler.@sections << section
  end

  def call(context)
    case context.request.path
    when "/status"
      respond_with_status context
    else
      call_next context
    end
  end

  macro inline(path)
    ECR.embed {{ path }}, __mAgiC_iO__
  end

  private def respond_with_status(context)
    title = PROGRAM_NAME
    if subpage = context.request.query_params["view"]?
      section = @sections.find { |s| s.class.name == subpage }
    end
    context.response.content_type = "text/html"
    io = __mAgiC_iO__ = context.response.output
    ECR.embed "./src/templates/index.html", io
  end
end
