schools = ["CENTRO DE PARTICIPAÇÃO POPULAR DO JARDIM VELOSO", "ASSOCIAÇÃO UNIÃO DE MÃES DO JARDIM DAS FLORES", "ASSOCIAÇÃO FAÇA UMA CRIANÇA SORRIR DE OSASCO E REGIÃO – NÚCLEO I", 
  "ASSOCIAÇÃO FAÇA UMA CRIANÇA SORRIR DE OSASCO E REGIÃO – NÚCLEO II ALFACRISO", "ASSOCIAÇÃO DAS MÃES DO JARDIM VELOSO", "ASSOCIAÇÃO QUINTAL MÁGICO", "CENTRO SOCIAL SANTO ANTONIO", 
  "ASSOCIAÇÃO PADRE DOMINGOS BARBÉ", "ASSOCIAÇÃO DE PROTEÇÃO À MATERNIDADE E À ADOLESCÊNCIA (ASPROMATINA) – PADRE GUERRINO",
  "ASCC – ASSOCIAÇÃO SOLIDÁRIA CRESCENDO CIDADÃ I - AÇUCARÁ", "ASCC – ASSOCIAÇÃO SOLIDÁRIA CRESCENDO CIDADÃ II – BELA VISTA", "ASSOCIAÇÃO DE EDUCAÇÃO POPULAR PIXOTE I" ,
  "ASSOCIAÇÃO DE EDUCAÇÃO POPULAR PIXOTE II", "ASSOCIAÇÃO DE PROTEÇÃO À MATERNIDADE E À ADOLESCÊNCIA (ASPROMATINA) – PADRE DOMINGOS TONINI", "LAR DA CRIANÇA EMMANUEL NÚCLEO KARDECISTA 21 DE ABRIL"]

schools.each do |ss|
  s = School.find_by_name(ss)
  Password.delete_all("school_id = #{s.id} AND segment_id = 21")
end