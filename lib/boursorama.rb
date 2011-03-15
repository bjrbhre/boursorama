# encoding: UTF-8

require "net/http"
require "nokogiri"

class Boursorama
  VERSION='0.1'

  class Page
    def initialize(session, url)
      @page = Nokogiri::HTML(session.get(url).body)
      p @page.search("ul.tabs a").map {|a| a.text}
    end
  end
  
  class Mouvement
    attr_reader :date, :name, :type, :value
    def initialize(node)
        date, @name, type, valuen, valuep = node[0].text, node[2].text.strip, node[2].at("div")["title"], node[3].text, node[4].text
        @date = Time.new(*date.split("/").reverse)
        value = valuen.empty? ? valuep : valuen
        @value = value.gsub(/[^0-9,-]/,'').sub(",", ".").to_f
        @type = type.sub("Nature de l'opération : ", "")
    end
  end 
    
  class Mouvements < Page
    include Enumerable
    def each; @list.each {|m| yield m} end
    def [](i); @list[i] end

    def initialize(session, url, date)
      url += "&month=#{date.month}&year=#{date.year}" if date
      super(session, url)
      @list = []
      @page.search("#customer-page tbody tr").each {|m|
         tds = m.search("td")
         next if tds.size < 6
         @list << Mouvement.new(tds)
      }
      @page = nil
    end
  end
  
  class Telechargement
    def initialize(session, bibliothequeAS400, fichierAS400, numeroMembre, nomFichier, numeroOrdre, isFichierDispo)
      @session, @bibliothequeAS400, @fichierAS400, @numeroMembre, @nomFichier, @numeroOrdre, @isFichierDispo = session, bibliothequeAS400, fichierAS400, numeroMembre, nomFichier, numeroOrdre, isFichierDispo
    end

    def name; @nomFichier end
    def body
      @session.post(TELECHARGEMENT) {|req|
        req.form_data = {
          'bibliothequeAS400' => @bibliothequeAS400,
          'fichierAS400' => @fichierAS400,
          'numeroMembre' => @numeroMembre,
          'nomFichier' => @nomFichier,
          'numeroOrdre' => @numeroOrdre,
          'isFichierDispo' => @isFichierDispo,
          'downloading' => "yes"
        }
      }.body
    end
  end
  
  class Telechargements < Page
    include Enumerable
    def each; @list.each {|m| yield m} end
    def [](i); @list[i] end

    def initialize(session, url)
      super(session, url)
      @list = []
      @page.search("form[name='telechargement'] input[name='infos']").each {|i|
        @list << Telechargement.new(@session, *i["onclick"].scan(/'([\w\.]+)'/).flatten)
      }
      @page = nil
    end
  end
      
  class Account
    class Releve
      attr_reader :name
      def initialize(session, name, url); @session, @name, @url = session, name, url end
      def body; @session.get(@url).body end
    end
    
    RELEVES_COMPTES_AJAX = "/ajax/clients/comptes/ereporting/releves_comptes_ajax.php"
    TELECHARGEMENT_CREATION = "/clients/comptes/banque/detail/telechargement_creation.phtml"
    TELECHARGEMENT = "/clients/comptes/banque/detail/telechargement.phtml"

    attr_reader :name, :number, :total
    def initialize(session, node)
      @session = session
      @name = node.at("td.account-name a").text
      @number = node.at("td.account-number").text.strip
      @total = node.at("td.account-total span").text
      @mouvements_url = node.at("td.account-more-actions a[id$=-mouvements]")['href']
      
      node.search("td.account-more-actions a").each {|a| p a['id'].split('-').map {|w| w.capitalize}.join if a['id']}
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
    
    def telechargement_creation(endtime = nil, starttime = nil, formatFichier = "X")
      endtime ||= Time.new
      starttime ||= endtime - 2678400
      res = @session.post(TELECHARGEMENT_CREATION) {|req| 
        req.form_data = {
                          'formatFichier' => formatFichier,
                          'periode1' => "choixUtilisateur",
                          'startTime' => starttime.strftime("%d/%m/%Y"),
                          'endTime' => endtime.strftime("%d/%m/%Y")
                         }
      }
    end
    
    def telechargements; Telechargements.new(@session, TELECHARGEMENT) end
    
    def mouvements(date = nil); Mouvements.new(@session, @mouvements_url, date) end
  end
  
  HOST = "www.boursorama.com"
  LOGIN = "/logunique.phtml"
  SYNTHESE = "/clients/synthese.phtml"
  USER_AGENT = "boursorama.rb/#{VERSION}"
  
  def get(url)
    http = Net::HTTP.new(HOST, 443)
    http.use_ssl = true
    req = Net::HTTP::Get.new(url)
    req["User-Agent"] = USER_AGENT
    req["Cookie"] = @cookies.map {|k,v| "#{k}=#{v}"}.join("; ")

    http.request(req)
  end
  
  def post(url)
    http = Net::HTTP.new(HOST, 443)
    http.use_ssl = true
    req = Net::HTTP::Post.new(url)
    req["User-Agent"] = USER_AGENT
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
  
  def page
    Page.new(self, "/clients/comptes/banque/detail/mouvements.phtml")
  end
end
