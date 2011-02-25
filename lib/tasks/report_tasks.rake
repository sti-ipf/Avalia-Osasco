namespace :reports do
  desc "Generate graphs for all institutions, in all service levels"
  task :graphs => :environment do
    dimensions = Dimension.all
    start_letter = ENV["START"] || "A"
    end_letter = ENV["END"] || ENV["START"] || "Z"

    # (start_letter.upcase..end_letter.upcase).each do |letter|
    #   Institution.all(:conditions => ["UPPER(name) LIKE ?", "#{letter.upcase}%"], :order => "name").each do |inst|
    #     puts inst.name
    #     inst.service_levels.each do |sl|
    #       puts "- #{sl.name}"
    #       rdata = ReportData.new(inst, sl)
    #       dimensions.each do |dimension|
    #         puts rdata.dimension_graph(dimension.number)
    #         puts rdata.indicators_graph(dimension.number)
    #       end
    #     end
    #   end
    # end
    
    inst = Institution.find(87)
    puts inst.name
    inst.service_levels.each do |sl|
      puts "- #{sl.name}"
      rdata = ReportData.new(inst, sl)
      not_generated = true
      dimensions.each do |dimension|
        sls = ServiceLevel.find(:all, :conditions => {:name => ['Creche','EMEI']})
        # rdata.service_level_graph(dimension, sls) if not_generated
        rdata.service_level_indicators_graph(dimension, sls)
        # rdata.dimension_graph(dimension)
        # rdata.indicators_graph(dimension)
        not_generated = false
      end
    end
  end
  
  desc "indicators by service_level"
  task :indicator_by_service_level => :environment do
    dimensions = Dimension.all

    not_generated = true
    sls = ServiceLevel.find(:all, :conditions => {:name => ['Creche','EMEI']})
    dimensions.each do |dimension|
      # rdata.service_level_graph(dimension, sls) if not_generated
      ReportData.service_level_indicators_graph(dimension, sls)
      # rdata.dimension_graph(dimension)
      # rdata.indicators_graph(dimension)
      not_generated = false
    end
  end
  
  desc "Generates graphs for each institution"
  task :reports => :environment do
    start_letter = ENV["START"] || "A"
    end_letter = ENV["END"] || "Z"
    
    # (start_letter.upcase..end_letter.upcase).each do |letter|
    #   Institution.all(:conditions => ["UPPER(name) LIKE ?", "#{letter.upcase}%"], :order => "name").each do |inst|
    #     puts inst.name
    #     inst.service_levels.each do |sl|
    #       puts "- #{sl.name}"
    #       ri = ReportIndividual.new
    #       ri.to_pdf(inst, sl)
    #     end
    #   end
    # end
    
    institution = Institution.find(87) #Maria José Ferreira Ferraz, Profª
    institution.service_levels.each do |service_level|
      puts "- #{service_level.name}"
      before = Time.now
      ri = ReportIndividual.new
      ri.to_pdf(institution, service_level, ReportData.new(institution, service_level))

      system "gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -dPDFSETTINGS=/printer -dAutoFilterColorImages=false -dColorImageFilter=/FlateEncode -sOutputFile=#{RAILS_ROOT}/public/relatorios/final/#{institution.id}_#{service_level.id}-final.pdf #{RAILS_ROOT}/public/relatorios/artifacts/capa_avalia.pdf #{RAILS_ROOT}/public/relatorios/artifacts/expediente.pdf #{RAILS_ROOT}/public/relatorios/final/#{institution.id}_#{service_level.id}.pdf"
      
      after = Time.now

      p "pdf generated in #{after - before}"
    end
  end

  namespace :generate do

    desc "Receives a pdf file to create a template, usage (absolute path) FILE=myfile.pdf"
    #you should have pdftopdf and pdftk in your vm
    task :template do
      source_file = ENV['FILE']
      abort "FILE is mandatody" unless source_file
      remove_extension = lambda{|str| str.gsub(/\.pdf$/i, '') }
      dir_name =  remove_extension.call File.basename(source_file)
      template_path = File.dirname(File.expand_path(source_file) )

      Dir.chdir template_path
      puts `pdftk #{source_file} burst`
      Dir.glob("pg_*.pdf").each do |pdf_file|
        eps_file = remove_extension.call(pdf_file) << ".eps"
        puts "Converting #{pdf_file} to #{eps_file} ..."
        `pdftops -eps #{pdf_file} #{eps_file} 1> /dev/null 2> /dev/null`
        rm pdf_file, :verbose => false
      end
      rm "doc_data.txt", :verbose => false #pdftk metadata
      puts "Get files at #{template_path}"
    end
  end
end

