# encoding: UTF-8

class Array
  def sum_values
    map(&:to_f).reject(&:nan?).inject(:+)
  end

  def avg
    sum = sum_values
    sum ||= 0
    return 0 if length.to_f == 0
    sum / length.to_f
  end
end

class Hash
  def avg
    values.avg
  end

  def sum_values
    values.sum_values
  end
end

class Institution < ActiveRecord::Base
  has_and_belongs_to_many :service_levels
  has_many :users
  has_many :groups, :through => :users, :uniq => true

  named_scope :by_group, proc { |group| {:conditions => ["groups.id = ?", group.id], :include => {:users => :group}} }
  named_scope :by_service_level, proc { |service_level| {:conditions => ["service_levels.id = ?", service_level.id], :include => :service_levels} }

  def <=>(other)
    name <=> other.name
  end

  def self.mean_dimension_by_sl(dimension,service_level)
    indicators = dimension.indicators.by_service_level(service_level)
    dimension_mean = { :mean => 0 }
    indicators_means = []
    @users_data = Hash.new { |h, k| h[k] = Hash.new }
    indicators.each do |indicator|
      questions_parties = indicator.questions_parties
      indicator_means = []
      questions_means = []
      questions_parties.each do |qp|
        qp.questions.each do |q|
          @curr_answers = {}
          answers = q.answers.valid.by_service_level(service_level).min_participants(0).newer
          answers.each do |a|
            @curr_answers[a.user_id] ||= a.mean 
            @users_data[a.user_id][a.question_id] ||= a
          end
            questions_means << @curr_answers.avg
        end
      end
        indicators_means << questions_means.avg
    end
    #if indicators_means.size > 0
      dimension_mean[:mean] = indicators_means.avg
    #end
    dimension_mean[:segments] = Institution.mean_by_segments(@users_data)
    dimension_mean[:mean] = dimension_mean[:segments].avg
    dimension_mean
  end

  def self.mean_indicator_by_sl(indicators_party,service_level)
    indicators = indicators_party.indicators
    indicator_mean = { :mean => 0 }
    indicators_party_means = []
    @users_data = Hash.new { |h, k| h[k] = Hash.new }
    indicators.each do |indicator|
      questions_parties = indicator.questions_parties
      indicator_means = []
      questions_means = []
      questions_parties.each do |qp|
        qp.questions.each do |q|
          @curr_answers = {}
          answers       = q.answers.valid.by_service_level(service_level).min_participants(0).newer
          answers.each do |a|
            @curr_answers[a.user_id] ||= a.mean 
            @users_data[a.user_id][a.question_id] ||= a 
          end
          #if @curr_answers.keys.size > 0
            questions_means << @curr_answers.avg
          #end
        end
      end
      #if questions_means.size > 0
        indicators_party_means << questions_means.avg
      #end
    end
    #if indicators_party_means.size > 0
      indicator_mean[:mean] = indicators_party_means.avg
    #end
    indicator_mean[:segments] = Institution.mean_by_segments(@users_data)
    indicator_mean[:mean] = indicator_mean[:segments].avg
    indicator_mean
  end

  def self.mean_questions_parties_by_sl(indicator,service_level)
    questions_parties_mean = { :sl => {} }
    questions_parties = indicator.questions_parties
    parties = {}
    questions_parties.each do |qp|
      questions_mean = []
      @curr_answers = {}
      qp.questions.each do |q|
        answers = q.answers.valid.by_service_level(service_level).min_participants(0).newer
        answers.each do |a|
          @curr_answers[a.user_id] ||= a.mean
        end
        #if @curr_answers.keys.size > 0
          questions_mean << @curr_answers.avg
        #end
      end
      #if questions_mean.size > 0
        questions_parties_mean[:sl][qp.id] = questions_mean.avg
      #end
    end
    questions_parties_mean
  end

  def self.mean_indicator_by_group(indicators_party,service_level,group)
    indicators = indicators_party.indicators
    indicator_mean = { :mean => 0 }
    indicators_party_means = []
    @users_data = Hash.new { |h, k| h[k] = Hash.new }
    indicators.each do |indicator|
      questions_parties = indicator.questions_parties
      indicator_means = []
      questions_means = []
      questions_parties.each do |qp|
        qp.questions.each do |q|
          @curr_answers = {}
          answers = q.answers
          answers = q.answers.by_group(group).valid.min_participants(0).newer
          answers.each do |a|
            @curr_answers[a.user_id] ||= a.mean 
            @users_data[a.user_id][a.question_id] ||= a 
          end
          #if @curr_answers.keys.size > 0
            questions_means << @curr_answers.avg
          #end
        end
      end
      #if questions_means.size > 0
        indicators_party_means << questions_means.avg
      #end
    end
    #if indicators_party_means.size > 0
      indicator_mean[:mean] = indicators_party_means.avg
    #end
    indicator_mean[:segments] = Institution.mean_by_segments(@users_data)
    indicator_mean[:mean] = indicator_mean[:segments].avg
    indicator_mean
  end


  def self.mean_questions_parties_by_group(indicator, service_level, group)
    questions_parties_mean = { :group => {} }
    questions_parties = indicator.questions_parties
    parties = {}
    questions_parties.each do |qp|
      questions_mean = []
      @curr_answers = {}
      qp.questions.each do |q|
        answers = q.answers.by_group(group).valid.min_participants(0).newer
        answers.each do |a|
          @curr_answersa[a.user_id] = a.mean
        end
        #if @curr_answers.keys.size > 0
          questions_mean << @curr_answers.avg
        #end
      end
      #if questions_mean.size > 0
        questions_parties_mean[:group][qp.id] = questions_mean.avg
      #end
    end
    questions_parties_mean
  end


  def self.mean_dimension_by_group(dimension,service_level,group)
    indicators = dimension.indicators.all(:conditions => {:service_level_id => service_level})
    dimension_mean = { :mean => 0 }
    indicators_means = []
    @users_data = Hash.new { |h, k| h[k] = Hash.new }
    indicators.each do |indicator|
      questions_parties = indicator.questions_parties
      indicator_means = []
      questions_means = []
      questions_parties.each do |qp|
        qp.questions.each do |q|
          @curr_answers = {}
          answers = q.answers.by_group(group).valid.min_participants(0).newer
          answers.each do |a|
            @curr_answers[a.user_id] ||= a.mean 
            @users_data[a.user_id][a.question_id] ||= a 
          end
          #if @curr_answers.keys.size > 0
            questions_means << @curr_answers.avg
          #end
        end
      end
      #if questions_means.size > 0
        indicators_means << questions_means.avg
      #end
    end
    #if indicators_means.size > 0
      dimension_mean[:mean] = indicators_means.avg
    #end
    dimension_mean[:segments] = Institution.mean_by_segments(@users_data)
    dimension_mean[:mean] = dimension_mean[:segments].avg
    dimension_mean
  end

  def mean_questions_indicator(indicator,service_level)
    questions_parties = indicator.questions_parties
    means = {}
    questions_parties.each do |qp|
      qp.questions.each do |q|
        means[q] = mean_questions(qp.id)
      end
    end
    means
  end
  
  def mean_questions(party_id)
    questions = QuestionsParty.find(party_id)
    mean = {}
    questions.each do |q|
      answers = q.answers
      answers = anwsers.by_service_level(service_level).valid.min_participants(0).newer
      curr_answer = {}
      answers.each do |a|
        @curr_answers[a.user_id] ||= a.mean
      end
      #if @curr_answers.keys.size > 0
        answer = @curr_answers.avg.round(2)
        mean[q.survey.segment.name] =  [q.number,answer]
      #end
    end
    mean
  end

  def mean_dimension(dimension,service_level)
    indicators = dimension.indicators.select { |i| i.service_level == service_level }
    dimension_mean = { :mean => 0 }
    indicators_means = []
    @users_data = Hash.new { |h, k| h[k] = Hash.new }
    indicators.each do |indicator|
      questions_parties = indicator.questions_parties
      indicator_means = []
      questions_means = []
      questions_parties.each do |qp|
        qp.questions.each do |q|
          @curr_answers = {}
          answers = q.answers.with_institution(self).by_service_level(service_level).valid.min_participants(0).newer
          answers.each do |a|
            @curr_answers[a.user_id] ||= a.mean
            @users_data[a.user_id][a.question_id] ||= a
          end
          #if @curr_answers.keys.size > 0
            questions_means << @curr_answers.avg
          #end
          #if questions_means.size > 0
            indicators_means << questions_means.avg
          #end
        end
      end
      #if indicators_means.size > 0
        dimension_mean[:mean] = indicators_means.avg
      #end
    end
    dimension_mean[:segments] = Institution.mean_by_segments(@users_data)
    dimension_mean[:mean] = dimension_mean[:segments].avg
    dimension_mean
  end

  def mean_indicator(indicators_party,service_level)
    indicators = indicators_party.indicators
    indicator_mean = { :mean => 0 }
    indicators_party_means = []
    @users_data = Hash.new { |h, k| h[k] = Hash.new }
    indicators.each do |indicator|
      questions_parties = indicator.questions_parties
      indicator_means = []
      questions_means = []
      questions_parties.each do |qp|
        qp.questions.each do |q|
          @curr_answers = {}
          answers = q.answers.with_institution(self).by_service_level(service_level).valid.min_participants(0).newer
          unless answers.nil?
            answers.each do |a|
              @curr_answers[a.user_id] ||= a.mean
              @users_data[a.user_id][a.question_id] ||= a
            end
            #if @curr_answers.keys.size > 0
              questions_means << @curr_answers.avg
            #end
          end
          #if questions_means.size > 0
            indicators_party_means << questions_means.avg
          #end
        end
      end
      #if indicators_party_means.size > 0
        indicator_mean[:mean] = indicators_party_means.avg
      #end
    end
    indicator_mean[:segments] = Institution.mean_by_segments(@users_data)
    indicator_mean[:mean] = indicator_mean[:segments].avg
    indicator_mean
  end

  def graph(mean, mean_group, mean_sl, service_level, options = {})
    indicators = options[:indicators]
    segments = service_level.segments.sort

    # Graph labels
    graph_labels =  {}

    # Graph data
    graph_data = segments.inject(Hash.new { |h, k| h[k] = [] }) do |hash, seg|
      hash["Media da UE"] << mean[:segments][seg.name].to_f
      hash["Media do Grupo"] << mean_group[:segments][seg.name].to_f
      hash["Media das #{service_level.name}s"] << mean_sl[:segments][seg.name].to_f

      graph_labels[graph_labels.length] = indicators.present? ? "#{seg.name}\n(#{indicators[seg.name]})" : seg.name
      hash
    end

    graph_data["Media da UE"] << mean[:mean]
    graph_data["Media do Grupo"] << mean_group[:mean]
    graph_data["Media das #{service_level.name}s"] << mean_sl[:mean]

    graph_labels[graph_labels.length] = "Geral"

    # table = Table(graph_labels.values, :data => graph_data.values)
    # puts table.to_text

    graph = UniFreire::Graphs::Base.new("450x300",
    :labels => graph_labels,
    :title => options[:title]
    )
    graph_data.each do |name, data|
      graph.data(name, data)
    end
    graph.data(" ", Array.new(segments.length, 0))
    graph.save_temporary("#{Rails.root}/tmp/graphs/#{id}/#{service_level.id}", "#{options[:id]}-")
  end

  def grade_to_table(mean_sl,mean_group,mean,sl)
    table = []
    header = ["Dimensão","Educandos","Familiares","Func. de Apoio","Gestores","Professores","Índice da UE","Índice do Grupo","Índice da Rede*"]
    header = header.reject { |i| i == "Educandos" } if sl.id != 2
    table << header

    col0  = ["1. Ambiente Educativo","2. Ambiente Físico Escolar e Materiais","3. Avaliação","4. Planejamento Institucional e Prática Pedagógica","5. Acesso e Permanência dos Educandos na Escola","6. Promoção da Saúde","7. Educação Socioambiental e Práticas Ecopedagógicas","8. Envolvimento com as Famílias e Participação na Rede de Proteção Social","9. Gestão Escolar Democrática","10. Formação e Condições de Trabalho dos Profissionais da Escola","11. Processos de Alfabetização e Letramento (Somente para as EMEFs)"]
    col0 = col0.reject { |i| i == "11. Processos de Alfabetização e Letramento (Somente para as EMEFs)" } if sl.id != 2

    sum   = 0
    names = sl.segments.collect { |seg| seg.name }.sort!

    col0.each_index do |index|
      dimension               = Dimension.find_by_number(index + 1)

      segments_dimension      = mean[dimension.id][:segments]
      grade_segments          = names.inject([]) {|array, name| array << (segments_dimension[name].to_f/5).round(2); array}

      average_dimension       = (((segments_dimension.sum_values.to_f)/names.length)/5).round(2)
      average_group_dimension = ((mean_group[dimension.id][:segments].sum_values.to_f/names.length)/5).round(2)
      average_sl_dimension       = ((mean_sl[dimension.id][:segments].sum_values.to_f/names.length)/5).round(2)

      value_row               = [average_dimension, average_group_dimension, average_sl_dimension]

      sum                     = sum + (((segments_dimension.sum_values.to_f)/names.length)/5)

      table << [col0[index]].concat(grade_segments).concat(value_row)
    end

    {:table => table, :institution_main_index => (sum.to_f/col0.size).round(2)}
  end

  def self.mean_by_segments(users_data)
    mean = {}
    data = {}
    users_data.each do |u_id,answers|
      u_mean = answers.values.map(&:mean).avg.round(2)
      u = User.find(u_id, :include => :segment)
      data[u.segment.name] ||= []
      data[u.segment.name] << u_mean
    end
    data.each do |seg,values|
      mean[seg] = values.avg
    end
    mean
  end

  def service_level_graph(sl_average_by_dimension, service_level, options = {})
    segments = service_level.segments.sort

    # Graph labels
    graph_labels =  {}
    segments.collect(&:name).each {|k,v| graph_labels[graph_labels.length] = k}

    a={}
    sl_average_by_dimension.each do |i|
      avgs = i[1][:segments]
      graph_avgs = [avgs["Educandos"] ? avgs["Educandos"] : 0.0, avgs["Familiares"], avgs["Funcionarios"], avgs["Gestores"], avgs["Professores"]]
      a[i[0]] = graph_avgs
    end

    graph = UniFreire::Graphs::Base.new("450x300",
      :labels => graph_labels,
      :title => options[:title]
    )
    
    a.each {|name, data| graph.data(name, data)}

    graph.data(" ", Array.new(segments.length, 0))
    graph_path = "#{Rails.root}/tmp/graphs/#{id}"
    graph.save_temporary(graph_path, "general_average_dimension#{options[:id]}-")
  end


end
