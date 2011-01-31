require "net/http"
require "nokogiri"

class Boursorama
  class Account
    class Releve
      attr_reader :name
      def initialize(session, name, url); @session, @name, @url = session, name, url end
      def body; @session.get(@url).body end
    end
    
    RELEVES_COMPTES_AJAX = "/ajax/clients/comptes/ereporting/releves_comptes_ajax.php"
#    data = "univers=Banque&type_demande=cc&numero_compte='+numero_compte+'&starttime=&endtime=13/01/2011"
    
    attr_reader :name, :number, :total
    def initialize(session, node)
      @session = session
      @name = node.at("td.account-name a").text
      @number = node.at("td.account-number").text.strip
      @total = node.at("td.account-total span").text
#      @url = node.at("td.account-name a")["href"]
    end
    
    
    def releves(endtime = nil, starttime = nil)
      endtime ||= Time.new
      starttime ||= endtime - 2678400
      res = @session.post(RELEVES_COMPTES_AJAX) {|req| 
        req["X-Requested-With"] = "XMLHttpRequest"
        req.form_data = {
          'univers' => "Banque", 'type_demande' => "", 'numero_compte' => @number,
          'starttime' => starttime.strftime("%d/%m/%Y"), 'endtime' => endtime.strftime("%d/%m/%Y")}
      }
      
      doc = Nokogiri::HTML(res.body, nil, "iso-8859-1")
      doc.search("a").map {|r| Releve.new(@session, r.text.gsub("/", "\u2044"), r['href'])}
    end
  end
  
  HOST = "www.boursorama.com"
  LOGIN = "/logunique.phtml"
  SYNTHESE = "/clients/synthese.phtml"
  
  def get(url)
    http = Net::HTTP.new(HOST, 443)
    http.use_ssl = true
    req = Net::HTTP::Get.new(url)
    req["Cookie"] = @cookies.map {|k,v| "#{k}=#{v}"}.join("; ")
    
    http.request(req)
  end
  
  def post(url)
    http = Net::HTTP.new(HOST, 443)
    http.use_ssl = true
    req = Net::HTTP::Post.new(url)
    req["Cookie"] = @cookies.map {|k,v| "#{k}=#{v}"}.join("; ") if @cookies
    yield req if block_given?
    
    http.request(req)
  end
  
  def login(user, password)
    @cookies = nil
    res = post(LOGIN) {|req| req.form_data = {'login' => user, 'password' => password}}
    @cookies = Hash[*res.get_fields("set-cookie").map {|c| c.sub(/;.*$/, "").split("=") }.flatten]
  end

  def initialize(user, password)
    login(user, password)
    
    @synthese = Nokogiri::HTML(get(SYNTHESE).body)
  end
  
  def inspect; "#<#{self.class}:0x#{object_id}>" end

  def accounts
    @synthese.search("#synthese-list tr.L10").map {|acc| Account.new(self, acc) }
  end
end
