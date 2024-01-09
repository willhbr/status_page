class StatusPage::Handler
  include HTTP::Handler

  @sections = Array(Section).new

  def initialize(@path : String)
    @sections << StatusPage::ProgramInfo.new
  end

  def add_section(section)
    @sections << section
  end

  def call(context)
    path = context.request.path
    if path.starts_with? @path
      if path.ends_with? ".css"
        context.response.content_type = "text/css"
        ECR.embed "#{__DIR__}/templates/styles.css", context.response.output
      else
        respond_with_status context
      end
    else
      call_next context
    end
  end

  macro inline(path)
    ECR.embed "#{__DIR__}/#{ {{ path }} }", __mAgiC_iO__
  end

  private def respond_with_status(context)
    title = PROGRAM_NAME
    if subpage = context.request.query_params["view"]?
      section = @sections.find { |s| s.class.name == subpage }
    end
    context.response.content_type = "text/html"
    io = __mAgiC_iO__ = context.response.output
    ECR.embed "#{__DIR__}/templates/index.html", io
  end
end
