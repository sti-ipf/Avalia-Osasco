require 'rghost'

module UniFreire
  module Reports
    class RelatorioIndividualOsasco
      TEMPLATE_DIRECTORY = File.expand_path("../templates", __FILE__)
      GRAPH_DIRECTORY = Rails.root.join("tmp/graphs")

      def initialize(institution, service_level)
        @institution = institution
        @service_level = service_level
        @report_data = ReportData.new(@institution, @service_level)
      end

      def report
        @doc = RGhost::Document.new :paper => :A4, :margin => 0
        @doc.define_tags do
          tag :rtitle, :size => 1, :name => "PTSans-Bold"
          tag :font1, :name => 'HelveticaBold', :size => 12
          tag :font2, :name => 'HelveticaBold', :size => 14
        end

        @doc.before_page_create :except => 1 do |d|
          d.text_in :text => "%current_page%", :x => 20, :y => 0.5
        end

        @doc.image page_file(1)
        @doc.goto_row 10
        @doc.show "#{@institution.name}", :align => :page_center, :tag => :title
        @doc.next_page
        #Salta 9 paginas
        (2..10).each do |page|
          @doc.image page_file(page)
          @doc.next_page
        end
        @tpage = 11


        (1..11).each do |idx|
          # Dimensao 1
          break if idx > 1
          puts "Dimension: #{idx}"
          @doc.image page_file(tpage)
          @doc.moveto :x => 4, :y => 10
          @doc.image dimension_graph(1), :zoom => 80, :x => 4, :y => 10

          @doc.moveto :y => -2
  #        grid = RGhost::Grid::Matrix.new
  #        grid.column :title => "Segmento", :width => 4
  #        grid.column :title => "Nº da questão", :width => 2
  #        grid.column :title => "Média por segmento", :height => 3
  #        grid.column :title => "Média Questão", :height => 1
  #        grid.column :title => "Média Grupo", :height => 1
  #        grid.column :title => "Média da Rede*", :height => 1
  #        grid.data([
  #          ["Professores", 1, 0, 1, 0, 1],
  #          ["Funcionários", 1, 0, 1, 0, 1],
  #          ["Pais", 1, 0, 1, 0, 1],
  #          ["Alunos", 1, 0, 1, 0, 1]
  #        ])
  #        grid.style :border_lines

  #        doc.set grid

          # |Segmento|Nº da questão do segmento|Média por Segmento|Média Geral da Questão|Média do Grupo|Média da Rede*|


          @doc.next_page
          @doc.image page_file(tpage)

          indicators = Indicator.by_dimension(1)
          indicators.each_with_index do |indicator, i|
            if i > 1
              puts "Breaking!"
              @doc.next_page
              break
            end
            puts "Indicator #{indicator.number}. #{indicator.name}"
            imgname = indicator_graph(indicator.id)
            if imgname
              @doc.image imgname, :zoom => 80, :x => 4, :y => 10
              @doc.next_page
              @doc.image page_file(tpage)
              @tpage -= 2
              indicator_table(indicator)
              @doc.next_page
            end
          end
        end

        @doc.image page_file(tpage)

        @doc.render :pdf, :filename => Rails.root.join("public/relatorios/new/#{@institution.name.underscore.gsub(' ', '_')}-#{@service_level.name.underscore}.pdf"), :quality => :prepress
      end

      def tpage
        @tpage ||= 0
        @tpage += 1
        @tpage - 1
      end

      def indicator_graph(id)
        fetch_file(File.join(GRAPH_DIRECTORY, "/#{@institution.id}/i#{id}-graph.jpg")) { @report_data.indicator_graph(id) }
      end

      def indicator_table(indicator)
        result = @report_data.indicator_table(indicator)
        @doc.moveto :x => 1, :y => 24
        @doc.text_area "#{result.question.description}", :x => 1.5, :y => 24, :width => 19
#         @doc.moveto :x => 1, :y => 1

        #draw the grid
        @doc.image File.join(TEMPLATE_DIRECTORY, "tabela_media.eps"), :x => 0, :y => -2

        start_axis_y = 21.1
        start_axis_x = 5.7
        row_height = 0.87
        x,y = start_axis_x, start_axis_y

        result.question_numbers.each_with_index do |q,i|
          @doc.moveto :x => x, :y => y
          @doc.show q, :align => :show_left, :tag => :font1
          y-=row_height
        end

        start_axis_x+=4.2
        x,y = start_axis_x, start_axis_y

        result.mean_by_segment.each_with_index do |m,i|
          @doc.moveto :x => x, :y => y
          @doc.show m, :align => :show_left, :tag => :font1
          y-=row_height
        end

        start_axis_x+= 3
        x,y = start_axis_x, start_axis_y
        center_y = y-(row_height*2)
        @doc.moveto :x => x, :y => center_y
        @doc.show result.question_mean, :align => :show_left, :tag => :font2

        @doc.moveto :x => x+2.6, :y => center_y
        @doc.show result.group_mean, :align => :show_left, :tag => :font2

        @doc.moveto :x => x+5.2, :y => center_y
        @doc.show result.sl_mean, :align => :show_left, :tag => :font2
      end

      def dimension_graph(number)
        fetch_file(File.join(GRAPH_DIRECTORY, "/#{@institution.id}/d#{number}-graph.jpg")) { @report_data.dimension_graph(number) }
      end

      def fetch_file(expected)
        return expected if File.exists?(expected)
        yield
      end

      def page_file(number)
        File.expand_path "pg_%04d.eps" % number, TEMPLATE_DIRECTORY
      end
    end
  end
end

