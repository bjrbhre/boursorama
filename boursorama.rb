# encoding: UTF-8

require "net/http"
require "nokogiri"

class Boursorama
  class Account
    Mouvement = Struct.new(:date, :name, :type, :value)
    
    class Releve
      attr_reader :name
      def initialize(session, name, url); @session, @name, @url = session, name, url end
      def body; @session.get(@url).body end
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
    
    MOUVEMENTS = "/clients/comptes/banque/detail/mouvements.phtml"
    RELEVES_COMPTES_AJAX = "/ajax/clients/comptes/ereporting/releves_comptes_ajax.php"
    TELECHARGEMENT_CREATION = "/clients/comptes/banque/detail/telechargement_creation.phtml"
    TELECHARGEMENT = "/clients/comptes/banque/detail/telechargement.phtml"

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
    
    def telechargements
      doc = Nokogiri::HTML(@session.get(TELECHARGEMENT).body)
      doc.search("form[name='telechargement'] input[name='infos']").map {|i|
        Telechargement.new(@session, *i["onclick"].scan(/'([\w\.]+)'/).flatten)
      }
    end
    
    def mouvements(date = nil)
      url = MOUVEMENTS
      url += "?month=#{date.month}&year=#{date.year}" if date
      doc = Nokogiri::HTML(@session.get(url).body)
      doc.search("#customer-page tbody tr").map {|m|
         tds = m.search("td")
         next if tds.size == 0 or tds.size < 6
         date, name, type, valuen, valuep = tds[0].text, tds[2].text.strip, tds[2].at("div")["title"], tds[3].text, tds[4].text
         date = Time.new(*date.split("/").reverse)
         value = valuen.empty? ? valuep : valuen
         value = value.gsub(/[^0-9,-]/,'').sub(",", ".").to_f
         type.sub!("Nature de l'opération : ", "")
         Mouvement.new date, name, type, value
      }.compact
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
