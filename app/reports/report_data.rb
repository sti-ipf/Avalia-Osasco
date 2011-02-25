# encoding: UTF-8
require 'ostruct'

class ReportData

  attr_reader :dimensions_sl
  attr_reader :dimensions_group

  attr_accessor :institution
  attr_accessor :service_level

  def initialize(institution,service_level)
    @institution = institution
    @service_level = service_level

    @dimensions_sl = {}
    @dimensions_group = {}

    begin
      first_user = @institution.users.first(:conditions => {:service_level_id => @service_level.id}, :include => :group)
      @group = first_user.group
    rescue
      puts "#{@institution.name} does not have a user in service level #{@service_level.name}"
    end
  end

  def questions_party_table(ue,questions_party)
    data = [["Segmento", "Nº da questão do segmento", " Média por Segmento", "Média Geral da Questão", "Média do Grupo", "Média da Rede*"]]

    segments_strings = %W(Educandos Familiares Funcionários Gestores Professores)
    # segments_strings.reject!{|i|i =="Educandos"} unless @service_level.name == "EMEF"
    
    segments =  segments_strings.map { |sname| Segment.first(:conditions => {:name => sname}) }.compact
   
    psegment = segments.select { |s| s.name == "Professores" }.first
    questions_party = QuestionsParty.find(questions_party, :include => {:questions => :indicator})
    display_question = questions_party.questions.first(:include => [:survey], :conditions => ["surveys.segment_id = ?", psegment.id])
    display_question ||= questions_party.questions.first(:conditions => "description is not null")

    segments.each_with_index do |segment, i|
      question = questions_party.questions.first(:include => [:survey], :conditions => ["surveys.segment_id = ?", segment.id])
      row = [segment.name]
      row << (question.nil? ? "-" : question.number)

      if question.present?
        answers = question.answers.with_institution(ue).by_service_level(service_level).min_participants(0).newer
        current_answer = answers.map(&:mean).avg.to_f.round(2)
        current_answer = current_answer > 0 ? current_answer : "NR"
        row << current_answer
      else
        row << "-"
      end

      if i == 2
        answers = questions_party.questions.map {|q| q.answers.with_institution(ue).by_service_level(service_level).min_participants(0).newer}.compact
        mean = []
        answers.each do |a|
          mean << a.map(&:mean)
        end
        row << mean.collect{|i| i.avg}.avg.to_f.round(2)
        if @group.present?
          row << questions_party.mean_by_group(@group).to_f.round(2) #Media do Grupo
        else
          row << "-"
        end
        row << questions_party.mean_by_sl.to_f.round(2) # media da rede
      else
        3.times { row << "" }
      end
      data << row
    end
    {
      :description => display_question.description.nil? ? display_question.description : display_question.description.gsub(/^[0-9]+\.[0-9]+\.[0-9]+/,''), 
      :table => data
    }
  end

  def dimension_graph(dimension)
    graph_start_time = now = Time.now

    data_sl = Institution.mean_dimension_by_sl(dimension, @service_level)
    #p data_sl
    sl_time = Time.now - now
    now = Time.now
    # p data_sl
    
    p "Graph Dimension: #{dimension.number}. #{dimension.name}"

    group = @institution.users.first(:conditions => {:service_level_id => @service_level.id}, :include => :group).group
    data_group = Institution.mean_dimension_by_group(dimension, @service_level, group)
    #p data_group
    group_time = Time.now - now
    now = Time.now
    
    data = @institution.mean_dimension(dimension, @service_level)
    #p data
    dimension_time = Time.now - now
    now = Time.now
    graph = @institution.graph(data, data_group, data_sl, @service_level, :id => dimension.number)
    p_times(graph, :sl => sl_time, :group => group_time, :dimension => dimension_time, :graph => Time.now - now, :total => Time.now - graph_start_time)

    graph
  end

  def service_level_graph(dimension, service_levels)
    graph_start_time = now = Time.now
    data_service_level = {}
    service_levels.each do |service_level|
      service_level_average_data = Institution.mean_dimension_by_sl(dimension, service_level)
      data_service_level[service_level.name] = service_level_average_data#.reject{|k,v| k == :mean}
    end
    service_level_time = Time.now - now
    now = Time.now
    p "Graph Service Level Dimension: #{dimension.number}. #{dimension.name}"
    dimension_time = Time.now - now
    
    now = Time.now
    graph = Institution.service_level_graph(data_service_level, :id => dimension.number, :group => "Ensino Infantil")
    graph_time = Time.now - now

    p_times(graph, :sl => service_level_time, :dimension => dimension_time, :graph => graph_time, :total => Time.now - graph_start_time)
  end

  def indicators_graph(dimension)
    indicators_parties = dimension.indicators_parties.all(:conditions => {:service_level_id => @service_level.id})
    filenames = indicators_parties.inject([]) do |list, indicators_party|
      list << indicator_graph(indicators_party)
    end
  end

  def indicator_graph(indicators_party)
    now = graph_start_time = Time.now
    data_sl = Institution.mean_indicator_by_sl(indicators_party, @service_level)
    #p data_sl
    sl_time = Time.now - now
    now = Time.now

    data_group = Institution.mean_indicator_by_group(indicators_party,@service_level, @group)
    #p data_group
    group_time = Time.now - now
    
    now = Time.now
    data = @institution.mean_indicator(indicators_party,@service_level)
    #p data
    indicators = {}
    indicators_party.indicators.each do |i|
      indicators[i.segment.name] = i.number
    end
    graph = @institution.graph(data, data_group, data_sl, @service_level, :id => "i#{indicators_party.id}", :title => "#{indicators_party.indicators.first.name}", :indicators => indicators)
    now2 = Time.now
    
    p_times(graph, :sl => sl_time, :group => group_time, :graph => now2 - now, :total => now2 - graph_start_time)
    #p "=============================================================================================================="
    graph
  end

  def p_times(filename, times={})
    t = []
    times.to_a.reverse.each do |k, v|
      t << ("%s: %0.3f" % [k, v])
    end
    p "Generated #{File.basename(filename)} (#{t.join(", ")})"
  end

  def index_table
    means_sl = {}
    means_group = {}
    means = {}
    dimensions = @service_level.id == 2 ? (1..11) : (1..10)
    
    dimensions.each do |dim|
      d = Dimension.find_by_number(dim)

      data_sl = Institution.mean_dimension_by_sl(d,@service_level)
      means_sl[d.id] = data_sl

  

      g = (@institution.users.select { |u| u.service_level == @service_level }).first.group
      data_group = Institution.mean_dimension_by_group(d,@service_level,g)
      means_group[d.id] = data_group
   

      data = @institution.mean_dimension(d,@service_level)
      means[d.id] = data
    end
    
    @institution.grade_to_table(means_sl,means_group,means,@service_level)
  end

  def service_level_group_table(service_level)
    members_groups = {
    "Creche" => [["grupo 1","grupo 2","grupo 3","grupo 4"],["Creche Benedita de Oliveira","Creche Elza Batiston","Creche Vilma Catan","Creche Amélia Tozzeto"],["CEMEI Lourdes Candida","Creche Sadamitu Omosako","Creche Maria José da Anunciação","Creche José Espinosa"],["CEMEI Wilma Foltran","Creche Prof. Silvia Ferreira Farhat","Creche Seraphina Bissolati","Creche Alha Elias Abib"],["CEMEIEF Maria José Ferreira Ferraz","CEU Zilda Arns","CEMEIEF Maria Tarsilla","Creche Giuseppa"],["CEMEI Rubens Bandeira","Creche Alzira Silva","Creche Lar da Infância","CEMEI José Ermírio"],["CEMEI João de Farias","Creche Olga Camolesi","Creche Pedro Penov","CEMEI Mário Quintana"],["Creche Prof. Joaquina França","CEMEI Leonil Crê","Creche Hermínia Lopes","Creche Mercedes Correa"], ["CEMEI Fortunato Antiório","Creche Rosa Broseguini","Creche Hilda","Creche Dayse Ribeiro"],["CEMEI Mário Sebastião","Creche Olímpia","Creche Rosa Pereira Crê","Creche Sergio Zanardi"],["CEMEIEF Darcy Ribeiro","Creche Ézio Melli","Creche Lídia Thomaz","Cemei Zaira Colino"],["  ","  ","Creche João Correa","Creche Recanto Alegre"],["  ","  ","Creche Ida Belmonte","CEMEI Alberto Santos Dumont"],["  ","  "," ","Creche Inês Sanches Mendes"],["  ","  "," ","Creche Irmã B. Constâncio e Creche Moacyr Ayres"]],

    "EMEI" => [["grupo 1","grupo 2","grupo 3","grupo 4"],["EMEI Maria Bertoni Fiorita","EMEI Maria Alves Dória","EMEI Helena Coutinho","CEMEI Zaíra Collino"],["EMEI Omar Ogeda","EMEI Nair Bellacoza","EMEI Pedro Martino","EMEI Cristine"],["EMEI Japhet Fontes","EMEIEF Valter de Oliveira","EMEI Maria Madalena Freixeda","CEMEI Alberto Santos Dumont"],["CEMEI Lourdes Candida","CEU Zilda Arns","EMEI Alípio Pereira","EMEI Osvaldo Salles"],["CEMEI Wilma Foltran","EMEI Gertrudes de Rossi","EMEI Estevão Brett","EMEI Esmeralda"],["EMEI Osvaldo Gonçalves","CEMEI Leonil Crê","CEMEIEF Maria Tarcilla","EMEIEF Messias"],["EMEI Yolanda Botaro","EMEI Sonia Maria ","EMEI Dalva Mirian","EMEI Emir Macedo"], ["CEMEI Fortunato Antiório","EMEI Maria Ap. Damy","EMEI Fernando Buonaduce","EMEI Descio Mendes"],["CEMEI Mário Sebastião","EMEIEF Colinas D Oeste","EMEI Alice Manholer Pitteri","EMEIEF Zuleika"],["CEMEIEF Darcy Ribeiro","  ","EMEI Fortunata","CEMEI José Emírio"],["EMEI Vivaldo","  ","EMEI Elide Alves","CEMEI Mário Quintana"],["CEMEIEF Maria José Ferreira Ferraz","  ","EMEI Adhemar Pereira","EMEI Salvador Sacco"],["CEMEI Rubens Bandeira","  ","EMEIF Etiene","EMEI Adelaide Dias"],["CEMEI João de Farias"," ","EMEI Providencia dos Anjos"," "],["EMEI José Flávio","  ","EMEI Ignes Collino","  "],["EMEIEF Elio Aparecido da Silva","  ","EMEI Severino","  "],["  ","  ","EMEI Luzia Momi Sasso","  "],["  ","  ","EMEI Antonio Paulino","  "],["  ","  ","EMEI Thereza Bianchi Colino","  "]],

    "EMEF" => [["grupo 1","grupo 2","grupo 3","grupo 4"],["Unidades Educacionais que não atingiram a meta projetada para ela em 2007 e apresentam IDEB inferior ao da rede municipal.","Unidades Educacionais que atingiram ou ultrapassaram a meta projetada para ela em 2007 mas mantiveram o seu IDEB inferior ao da rede municipal.","Unidades Educacionais que não atingiram a meta projetada para ela em 2007 e apresentaram IDEB igual ou superior ao da rede municipal.","Unidades Educacionais que atingiram ou ultrapassaram a meta projetada para ela em 2007 e apresentaram IDEB igual ou superior ao da rede municipal"]]
    }
    name = service_level.name.upcase
    {:title => name == "CRECHE" ? name + "S" : name + "s", :table => members_groups[service_level.name] }
  end

  def single_institution_dimension_graph(dimension)
    graph_start_time = now = Time.now

    data_sl = Institution.mean_dimension_by_sl(dimension, @service_level)
    #p data_sl
    sl_time = Time.now - now
    now = Time.now
    # p data_sl
    
    p "Single Institution Dimension Graph : #{dimension.number}. #{dimension.name}"

    group = @institution.users.first(:conditions => {:service_level_id => @service_level.id}, :include => :group).group
    data_group = Institution.mean_dimension_by_group(dimension, @service_level, group)
    #p data_group
    group_time = Time.now - now
    now = Time.now
    
    data = @institution.mean_dimension(dimension, @service_level)
    #p data
    dimension_time = Time.now - now
    now = Time.now
    graph = @institution.single_institution_graph(data, data_group, data_sl, @service_level, :id => "dimension#{dimension.number}")
    p_times(graph, :sl => sl_time, :group => group_time, :dimension => dimension_time, :graph => Time.now - now, :total => Time.now - graph_start_time)

    graph
  end

  def single_institution_indicators_graph(dimension)
    indicators_parties = dimension.indicators_parties.all(:conditions => {:service_level_id => @service_level.id})
    filenames = indicators_parties.inject([]) do |list, indicators_party|
      list << single_institution_indicator_graph(indicators_party)
    end
  end

  def single_institution_indicator_graph(indicators_party)
    now = graph_start_time = Time.now
    data_sl = Institution.mean_indicator_by_sl(indicators_party, @service_level)
    #p data_sl
    sl_time = Time.now - now
    now = Time.now

    data_group = Institution.mean_indicator_by_group(indicators_party,@service_level, @group)
    #p data_group
    group_time = Time.now - now
    
    now = Time.now
    data = @institution.mean_indicator(indicators_party,@service_level)
    #p data
    indicators = {}
    indicators_party.indicators.each do |i|
      indicators[i.segment.name] = i.number
    end
    graph = @institution.single_institution_graph(data, data_group, data_sl, @service_level, :id => "single_institution_i#{indicators_party.id}", :title => "#{indicators_party.indicators.first.name}", :indicators => indicators)
    now2 = Time.now
    
    p_times(graph, :sl => sl_time, :group => group_time, :graph => now2 - now, :total => now2 - graph_start_time)
    graph
  end

  
  def self.service_level_indicators_graph(dimension,sls)
    # indicators_parties = dimension.indicators_parties.all(:conditions => {:service_level_id => sls.collect(&:id)})
    indicators_parties = IndicatorsParty.find(:all, :conditions => {
        :service_level_id => sls.collect(&:id),
        :dimension_id => dimension.id
      }
    )
    data = sls.inject({}) {|m,v| m[v.name]= indicators_parties.find_all {|i|i.service_level_id == v.id};m}
    indicators_parties.each {|indicators_party| service_level_indicator_graph(indicators_party, sls)}
    # service_level_indicator_graph(indicators_party, data)
  end

  def self.service_level_indicator_graph(indicators_party, sls)
    now = graph_start_time = Time.now
    # data_sl = {:mean=>0.0, :segments=>{"Professores"=>0.0, "Familiares"=>0.0, "Funcionarios"=>0.0, "Gestores"=>0.0}}
    blur={}
    sls.each do |i|
      # {:mean=>4.37266173042644, :segments=>{"Professores"=>4.22963636363636, "Familiares"=>4.44846153846154, "Funcionarios"=>4.21, "Gestores"=>4.60254901960784}}
      # temp = Institution.mean_indicator_by_sl(indicators_party, i)
      # data_sl[:mean] = data_sl[:mean] + temp[:mean]
      # temp[:segments].each_pair do |k,v|
      #   data_sl[:segments][k] = data_sl[:segments][k] + temp[:segments][k]
      # end
      blur[i.name] = Institution.mean_indicator_by_sl2(indicators_party, sls)
    end
    #p data_sl
    sl_time = Time.now - now
    now = Time.now

    # data_group = Institution.mean_indicator_by_group(indicators_party,@service_level, @group)
    # #p data_group
    # group_time = Time.now - now
    # 
    # now = Time.now
    # data = @institution.mean_indicator(indicators_party,@service_level)
    #p data
    # graph = @institution.graph(data, data_group, data_sl, @service_level, :id => "i#{indicators_party.id}", :title => "#{indicators_party.indicators.first.name}", :indicators => indicators)
    p "============"
    p blur
    graph = Institution.service_level_graph(blur, :id => "i#{indicators_party.indicators.first.number}", :title => "#{indicators_party.indicators.first.name}", :group => "Ensino Infantil")
    now2 = Time.now
    
    # p_times(graph, :sl => sl_time,:graph => now2 - now)
    #p "=============================================================================================================="
    # graph
  end

end

