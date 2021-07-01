global class BatchComprasClientesProdutos implements Database.Batchable<sObject>, Database.Stateful, Schedulable {
    
    String query;
	List<String> listError;
	List<Account> listContas;
    
    private Integer periodoApuracao = Toolkit.getPeriodoMeta();

    global BatchComprasClientesProdutos() {
		listError = new List<String>();
		listContas = new List<Account>();
		

	}
	
	global Database.QueryLocator start(Database.BatchableContext BC) {
				query = 'SELECT Id,  Name, Compras_Recorrentes__c, Compras_Per_Call__c, Compras_FindUP_People__c, Compras_Avulsas__c, Compras_Piloto__c, Compras_Projetos__c, Compras_Insumo__c '
					+ 'FROM Account WHERE Cliente_da_Base__c = TRUE';
                
		return Database.getQueryLocator(query);
	}

   	global void execute(Database.BatchableContext BC, List<sObject> scope) {
		List<Account> clientes = (List<Account>) scope;

		for (Account conta : clientes) {
						
			List<AggregateResult> ars;

            ars = [SELECT COUNT(Id) total, Produto_FindUP__c, Data_do_Neg_cio_Fechado_F__c FROM Opportunity
                WHERE IsWon = true 
				    AND Amount > 10
                    AND AccountId = :conta.Id
                    GROUP BY Produto_FindUP__c, Data_do_Neg_cio_Fechado_F__c
					ORDER BY Data_do_Neg_cio_Fechado_F__c DESC Limit 3];

				for(AggregateResult opp: ars){
					if((String)opp.get('Produto_FindUP__c') == 'FindUP People' || (String)opp.get('Produto_FindUP__c') == 'FindUP People Recorrente - Carga Automática'){
						conta.Compras_FindUP_People__c = (Integer) opp.get('total');
                    
					} else if((String)opp.get('Produto_FindUP__c') == 'Contrato Recorrente' || (String)opp.get('Produto_FindUP__c') == 'Recorrente - Carga Automática'){
						conta.Compras_Recorrentes__c = (Integer) opp.get('total');

					} else if((String)opp.get('Produto_FindUP__c') == 'Carga Avulsa'){
						conta.Compras_Avulsas__c = (Integer) opp.get('total');
						
					} else if((String)opp.get('Produto_FindUP__c') == 'Per Call'){
						conta.Compras_Per_Call__c = (Integer) opp.get('total');

					} else if((String)opp.get('Produto_FindUP__c') == 'Projetos em Clientes Avulsos' || (String)opp.get('Produto_FindUP__c') == 'Projetos em Clientes Recorrentes'){
						conta.Compras_Projetos__c = (Integer) opp.get('total');	

					} else if((String)opp.get('Produto_FindUP__c') == 'Fornecimento de Insumos'){
						conta.Compras_Insumo__c = (Integer) opp.get('total');

					} else if((String)opp.get('Produto_FindUP__c') == 'Piloto FindUP'){
						conta.Compras_Piloto__c = (Integer) opp.get('total');
					}
					
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

}