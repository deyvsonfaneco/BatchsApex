global class BatchComprasCliente implements Database.Batchable<sObject>, Database.Stateful, Schedulable {
    
    String query;
	List<String> listError;
	List<Account> listContas;
    
    private Integer periodoApuracao = Toolkit.getPeriodoMeta();

    global BatchComprasCliente() {
		listError = new List<String>();
		listContas = new List<Account>();
		

	}
	
	global Database.QueryLocator start(Database.BatchableContext BC) {
				query = 'SELECT Id,  Name, Compras_Recorrentes__c, M_dia_dias_para_Recompra__c, Soma_Oportunidades_Convertidas_no_mes__c, Total_de_Tickets_das_Oportunidades_Aut__c, Compras_Per_Call__c, Compras_Avulsas__c, Compras_Piloto__c, Compras_Projetos__c, Compras_Insumo__c '
					+ 'FROM Account WHERE Cliente_da_Base__c = TRUE';
                
		return Database.getQueryLocator(query);
	}

   	global void execute(Database.BatchableContext BC, List<sObject> scope) {
		List<Account> clientes = (List<Account>) scope;

		for (Account cli : clientes) {

			cli.M_dia_dias_para_Recompra__c= calcularMediaRecompras(cli);

			listContas.add(cli);

		}

		TriggerHandlerConta.ignoreTrigger = true;
		Toolkit.ignoraRegraValidacao(true);
		Database.SaveResult[] sr = Database.update(listContas, false);
		TriggerHandlerConta.ignoreTrigger = false;
		Toolkit.ignoraRegraValidacao(false);

		for(Database.SaveResult s : sr){
			if(!s.isSuccess()){
				listError.add(String.valueOf(s.getErrors()));
			}
		}

        if(listError != null && listError.size() > 0){
            System.debug('OCORREU ERRO: ' + listError);
        }

	}


	global void finish(Database.BatchableContext BC) {

	}

	global void execute(SchedulableContext sc) {
		Database.executeBatch( new BatchComprasCliente(), 10 );
	}  


    
    // Calcular média de Recompras
	private Integer calcularMediaRecompras(Account conta) {
        Date maxDate;
        Date minDate;
		Integer mediaDias;
		Integer qtdCompra;

		List<AggregateResult> opp1;
		opp1 = [SELECT MIN(Data_do_Neg_cio_Fechado_F__c) MediaM 
	           FROM Opportunity
			   WHERE IsWon = true
			   AND AccountId = : conta.Id];
        
        if (opp1.size() > 0 && opp1.get(0).get('MediaM') != null){
            minDate = (Date) opp1.get(0).get('MediaM');
		}
		// 
		List<AggregateResult> opp2;
		 opp2 = [SELECT MAX(Data_do_Neg_cio_Fechado_F__c) Media 
	             FROM Opportunity
				 WHERE isWon = true
				 AND AccountId = : conta.Id];
        
        if (opp2.size() > 0 && opp2.get(0).get('Media') != null){
         maxDate = (Date) opp2.get(0).get('Media');
         }
		//
		List<AggregateResult> opp3;
		 opp3 = [SELECT COUNT(Data_do_Neg_cio_Fechado_F__c) Total 
	             FROM Opportunity
				 WHERE isWon = true
				 AND AccountId = : conta.Id];
        
        if (opp3.size() > 0 && opp3.get(0).get('Total') != null){
         qtdCompra = (Integer) opp3.get(0).get('Total');
         }

		Integer numberDaysDue = minDate.daysBetween (maxDate);
		if(qtdCompra <= 1){
			mediaDias = 0;
		} else {
			mediaDias = numberDaysDue / (qtdCompra -1);
		}
        
        return mediaDias;
     }

     // ///////////////////////////////////////////////

     global class BatchComprasClientesProdutos implements Database.Batchable<sObject>, Database.Stateful, Schedulable {
    
        String query;
        List<String> listError;
        List<Account> listContas;
        
        
    
        global BatchComprasClientesProdutos() {
            listError = new List<String>();
            listContas = new List<Account>();
            
    
        }
        
        global Database.QueryLocator start(Database.BatchableContext BC) {
                    query = 'SELECT Id,  Name, Compras_Recorrentes__c, Compras_Per_Call__c, Tipo_da_Conta_Compra__c, Tipo_de_Compra_aut__c, Compras_FindUP_People__c, Compras_Avulsas__c, Compras_Piloto__c, Compras_Projetos__c, Compras_Insumo__c '
                        + 'FROM Account WHERE Cliente_da_Base__c = TRUE';
                    
            return Database.getQueryLocator(query);
        }
    
           global void execute(Database.BatchableContext BC, List<sObject> scope) {
            List<Account> clientes = (List<Account>) scope;
            for (Account conta : clientes) {
                conta.Compras_Avulsas__c = 0;
                conta.Compras_FindUP_People__c = 0;
                conta.Compras_Insumo__c = 0;
                conta.Compras_Projetos__c = 0;
                conta.Compras_Recorrentes__c = 0;
                conta.Compras_Per_Call__c = 0;
                conta.Compras_Piloto__c = 0;
                
                List<Opportunity> listCompras;
    
                listCompras = [SELECT Id , Produto_FindUP__c, Data_do_Neg_cio_Fechado_F__c FROM Opportunity
                               WHERE IsWon = true 
                               AND Amount > 10
                               AND AccountId = :conta.Id
                               ORDER BY Data_do_Neg_cio_Fechado_F__c DESC LIMIT 3];
    
                    Set<String> listComprasString = new Set<String>();
                    Boolean eRecorrente = false;
    
                    for(Opportunity opp: listCompras){
                        if(opp.Produto_FindUP__c == 'FindUP People' || opp.Produto_FindUP__c == 'FindUP People Recorrente - Carga Automática'){
                            conta.Compras_FindUP_People__c ++;
                            listComprasString.add('People');
                        
                        } else if(opp.Produto_FindUP__c == 'Contrato Recorrente' || opp.Produto_FindUP__c == 'Recorrente - Carga Automática'){
                            conta.Compras_Recorrentes__c ++;
                            listComprasString.add('Recorrente');
                            eRecorrente = true;
    
                        } else if(opp.Produto_FindUP__c == 'Carga Avulsa'){
                            conta.Compras_Avulsas__c ++;
                            listComprasString.add('Avulso');
                            
                        } else if(opp.Produto_FindUP__c == 'Per Call'){
                            conta.Compras_Per_Call__c ++;
                            listComprasString.add('Per Call');
    
                        } else if(opp.Produto_FindUP__c == 'Projetos em Clientes Avulsos' || opp.Produto_FindUP__c == 'Projetos em Clientes Recorrentes'){
                            conta.Compras_Projetos__c ++;	
                            listComprasString.add('Projeto');
    
                        } else if(opp.Produto_FindUP__c == 'Fornecimento de Insumos'){
                            conta.Compras_Insumo__c ++;
                            listComprasString.add('Insumo');
    
                        } else if(opp.Produto_FindUP__c == 'Piloto FindUP'){
                            conta.Compras_Piloto__c ++;
                            listComprasString.add('Piloto');
                        }
                        
                    }
                
                conta.Tipo_de_Compra_aut__c = getCompras(listComprasString);
                if(eRecorrente){
                    conta.Tipo_da_Conta_Compra__c = 'Recorrente';
                } else {
                    conta.Tipo_da_Conta_Compra__c = 'Avulso';
                }
    
                listContas.add(conta);
    
            }
    
            TriggerHandlerConta.ignoreTrigger = true;
            Toolkit.ignoraRegraValidacao(true);
            Database.SaveResult[] sr = Database.update(listContas, false);
            TriggerHandlerConta.ignoreTrigger = false;
            Toolkit.ignoraRegraValidacao(false);
    
            for(Database.SaveResult s : sr){
                if(!s.isSuccess()){
                    listError.add(String.valueOf(s.getErrors()));
                }
            }
    
            if(listError != null && listError.size() > 0){
                System.debug('OCORREU ERRO: ' + listError);
            }
    
        }
    
    
        global void finish(Database.BatchableContext BC) {
    
        }
    
        global void execute(SchedulableContext sc) {
            Database.executeBatch( new BatchComprasClientesProdutos(), 10 );
        }  
    
        private String getCompras(Set<String> listComprasString){
            String compraAdd = '';			
            for(String compra : listComprasString){
                compraAdd += compra+';';
            }
    
            return compraAdd;
        }
    
    }

    /////////////////////////////////////////////////

    global class BatchVerificaCompromissosConta implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {

        /**
         * Batch criado para atualizar os dados do compromisso com base no que o Murillo precisa de metrica.
         */
    
        String query;
        List<Account> listAccount;
        
        global BatchVerificaCompromissosConta() {
            listAccount = new List<Account>();		
        }
        
        global Database.QueryLocator start(Database.BatchableContext BC) {		
            String semPerfil = 'Sem Perfil';
            if(Test.isRunningTest()){
                query = 'SELECT Id, Name, QTD_Geral_de_Reuni_es_Realizadas__c, (SELECT Id, FirstName FROM Contacts), Data_do_Ultimo_Compromisso__c FROM Account WHERE Type != :semPerfil OR Classificacao_Cliente__c != :semPerfil LIMIT 1'; 
            } else {
                query = 'SELECT Id, Name, QTD_Geral_de_Reuni_es_Realizadas__c, (SELECT Id, FirstName FROM Contacts), Data_do_Ultimo_Compromisso__c FROM Account WHERE Type != :semPerfil OR Classificacao_Cliente__c != :semPerfil';
            }
            
            return Database.getQueryLocator(query);
        }
    
           global void execute(Database.BatchableContext BC, List<sObject> scope) {
               listAccount = (List<Account>) scope;
    
               for(Account conta : listAccount){
    
                    List<String> listContacts = new List<String>();
                    for(Contact contato : conta.Contacts){
                        listContacts.add( contato.Id );
                    }
    
                    conta.QTD_Geral_de_Reuni_es_Realizadas__c = getQTDGeraldeReuniao(conta, listContacts);	
               }
    
               TriggerHandlerConta.ignoreTrigger = true;
                Toolkit.ignoraRegraValidacao(true);
               Database.update(listAccount, false);
               TriggerHandlerConta.ignoreTrigger = false;
                Toolkit.ignoraRegraValidacao(false);
        }
        
        global void finish(Database.BatchableContext BC) {
            
        }
    
        global void execute(SchedulableContext sc) {
            Database.executeBatch( new BatchVerificaCompromissosConta(), 1);
        }
        
        /**
        * Métodos Privados do Batch
        * Pegar a ultima data do compromisso
        * ---------------------------------------------------------------------------------------------------------------------------
        */
        //Total de reuniões realizadas
        private Integer getQTDGeraldeReuniao(Account conta, List<String> listContacts){
            Integer qtdReuniao;
    
            List<AggregateResult> ars;
            ars = [SELECT COUNT(Id) total
                   FROM Event 
                   WHERE Classifica_o_do_Compromisso__c = 'Reunião Realizada' 
                   AND (WhatId = :conta.Id OR WhoId IN :listContacts )  
                   GROUP BY Classifica_o_do_Compromisso__c];
    
            if (ars.size() > 0 && ars.get(0).get('total') != null){
                qtdReuniao = (Integer) ars.get(0).get('total');
            }
            return qtdReuniao;     
        }

        ///////////////////////////////////////////////////////////////

        