import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class CobrAppRepository {
  SupabaseClient get db => supabase;
  String get uid { final user = db.auth.currentUser; if (user == null) { throw StateError('Usuário não autenticado.'); } return user.id; }

  Future<List<Map<String,dynamic>>> customers() async => List<Map<String,dynamic>>.from(await db.from('cobrapp_customers').select().eq('user_id',uid).order('name'));
  Future<void> addCustomer({required String name,String? phone,String? document,String? address,String? notes}) async => db.from('cobrapp_customers').insert({'user_id':uid,'name':name,'phone':phone,'document':document,'address':address,'notes':notes});
  Future<void> updateCustomer({required String id,required String name,String? phone,String? document,String? address,String? notes}) async => db.from('cobrapp_customers').update({'name':name,'phone':phone,'document':document,'address':address,'notes':notes}).eq('id',id).eq('user_id',uid);
  Future<void> deleteCustomer(String id) async => db.from('cobrapp_customers').delete().eq('id',id).eq('user_id',uid);

  Future<List<Map<String,dynamic>>> loans() async => List<Map<String,dynamic>>.from(await db.from('cobrapp_loans').select('*, cobrapp_customers(name), cobrapp_installments(id,number,due_date,amount,paid_amount,status)').eq('user_id',uid).order('created_at',ascending:false));
  Future<Map<String,dynamic>> addLoan({required String customerId,required double principal,required int installments,required double interest}) async => Map<String,dynamic>.from(await db.rpc('cobrapp_criar_emprestimo',params:{'p_customer_id':customerId,'p_principal':principal,'p_installments':installments,'p_interest_rate':interest}));

  Future<List<Map<String,dynamic>>> installments({String? loanId}) async {var q=db.from('cobrapp_installments').select('*, cobrapp_customers(name), cobrapp_loans(principal,interest_rate,status)'); q=q.eq('user_id',uid); if(loanId!=null)q=q.eq('loan_id',loanId); return List<Map<String,dynamic>>.from(await q.order('due_date'));}
  Future<List<Map<String,dynamic>>> receipts() async => List<Map<String,dynamic>>.from(await db.from('cobrapp_receipts').select('*, cobrapp_customers(name)').eq('user_id',uid).order('issued_at',ascending:false));
  Future<List<Map<String,dynamic>>> payments() async => List<Map<String,dynamic>>.from(await db.from('cobrapp_payments').select('amount,paid_at,type,customer_id').eq('user_id',uid).order('paid_at',ascending:false));
  Future<Map<String,dynamic>> addPayment({required String installmentId,required double amount,String? method,String? notes,String type='total'}) async => Map<String,dynamic>.from(await db.rpc('cobrapp_registrar_pagamento',params:{'p_installment_id':installmentId,'p_amount':amount,'p_method':method??'Dinheiro','p_notes':notes,'p_type':type}));

  Future<List<Map<String,dynamic>>> routes() async => List<Map<String,dynamic>>.from(await db.from('cobrapp_routes').select('*, cobrapp_customer_routes(customer_id, cobrapp_customers(id,name,phone,address))').eq('user_id',uid).order('name'));
  Future<void> addRoute({required String name,String? description}) async => db.from('cobrapp_routes').insert({'user_id':uid,'name':name,'description':description});
  Future<void> updateRoute({required String id,required String name,String? description}) async => db.from('cobrapp_routes').update({'name':name,'description':description}).eq('id',id).eq('user_id',uid);
  Future<void> deleteRoute(String id) async => db.from('cobrapp_routes').delete().eq('id',id).eq('user_id',uid);
  Future<void> assignCustomerToRoute({required String routeId,required String customerId}) async => db.from('cobrapp_customer_routes').upsert({'user_id':uid,'route_id':routeId,'customer_id':customerId},onConflict:'customer_id');
  Future<void> removeCustomerFromRoute({required String routeId,required String customerId}) async => db.from('cobrapp_customer_routes').delete().eq('route_id',routeId).eq('customer_id',customerId).eq('user_id',uid);

  Future<List<Map<String,dynamic>>> expenses() async => List<Map<String,dynamic>>.from(await db.from('cobrapp_expenses').select().eq('user_id',uid).order('spent_at',ascending:false));
  Future<void> addExpense({required double amount,required String description,String category='Geral'}) async => db.from('cobrapp_expenses').insert({'user_id':uid,'amount':amount,'description':description,'category':category});
  Future<void> deleteExpense(String id) async => db.from('cobrapp_expenses').delete().eq('id',id).eq('user_id',uid);

  Future<Map<String,dynamic>> portfolioReport({DateTime? from, DateTime? to}) async {
    final loans=List<Map<String,dynamic>>.from(await db.from('cobrapp_loans').select('id,customer_id,principal,total_amount,status,created_at,cobrapp_customers(name)').eq('user_id',uid).order('created_at',ascending:false));
    final installments=List<Map<String,dynamic>>.from(await db.from('cobrapp_installments').select('id,loan_id,customer_id,number,due_date,amount,paid_amount,status').eq('user_id',uid).order('due_date'));
    final payments=List<Map<String,dynamic>>.from(await db.from('cobrapp_payments').select('amount,paid_at,type,customer_id').eq('user_id',uid).order('paid_at',ascending:false));
    final expenses=List<Map<String,dynamic>>.from(await db.from('cobrapp_expenses').select('amount,spent_at,category').eq('user_id',uid).order('spent_at',ascending:false));
    bool inRange(String? value){ if(value==null)return true; final d=DateTime.tryParse(value); if(d==null)return true; if(from!=null && d.isBefore(DateTime(from.year,from.month,from.day)))return false; if(to!=null && d.isAfter(DateTime(to.year,to.month,to.day,23,59,59)))return false; return true; }
    final fp=payments.where((x)=>inRange(x['paid_at']?.toString())).toList();
    final fe=expenses.where((x)=>inRange(x['spent_at']?.toString())).toList();
    double sum(Iterable<Map<String,dynamic>> xs,String key)=>xs.fold<double>(0,(a,x)=>a+((x[key] as num?)?.toDouble()??0));
    final pending=installments.fold<double>(0,(a,x)=>a+(((x['amount'] as num?)?.toDouble()??0)-((x['paid_amount'] as num?)?.toDouble()??0)));
    final overdue=installments.where((x)=>x['status']!='paid' && (x['due_date']?.toString()??'').compareTo(DateTime.now().toIso8601String().substring(0,10)) < 0).fold<double>(0,(a,x)=>a+(((x['amount'] as num?)?.toDouble()??0)-((x['paid_amount'] as num?)?.toDouble()??0)));
    final customerMap=<String,Map<String,dynamic>>{};
    for(final x in loans){
      final id=x['customer_id'].toString();
      final c=x['cobrapp_customers'] as Map?;
      final row=customerMap.putIfAbsent(id,()=>{'id':id,'name':c?['name']??'Cliente','loans':0,'principal':0.0,'received':0.0,'pending':0.0});
      row['loans']=(row['loans'] as int)+1;
      row['principal']=(row['principal'] as double)+((x['principal'] as num?)?.toDouble()??0);
    }
    for(final x in installments){
      final id=x['customer_id'].toString();
      final row=customerMap[id];
      if(row!=null) row['pending']=(row['pending'] as double)+(((x['amount'] as num?)?.toDouble()??0)-((x['paid_amount'] as num?)?.toDouble()??0));
    }
    for(final x in fp){
      final id=x['customer_id']?.toString();
      final row=id==null?null:customerMap[id];
      if(row!=null) row['received']=(row['received'] as double)+((x['amount'] as num?)?.toDouble()??0);
    }
    return {'loans':loans,'installments':installments,'payments':fp,'expenses':fe,'loaned':loans.fold<double>(0,(a,x)=>a+((x['principal'] as num?)?.toDouble()??0)),'received':sum(fp,'amount'),'expensesTotal':sum(fe,'amount'),'balance':sum(fp,'amount')-sum(fe,'amount'),'pending':pending,'overdue':overdue,'customers':customerMap.values.toList()};
  }

  Future<Map<String,dynamic>> totals() async {
    final c=await db.from('cobrapp_customers').select('id').eq('user_id',uid);
    final l=await db.from('cobrapp_loans').select('principal,status,total_amount').eq('user_id',uid);
    final p=await db.from('cobrapp_payments').select('amount').eq('user_id',uid);
    final i=await db.from('cobrapp_installments').select('amount,paid_amount,status,due_date').eq('user_id',uid);
    final e=await db.from('cobrapp_expenses').select('amount').eq('user_id',uid);
    double loans=0,payments=0,pending=0,expenses=0;
    for (final x in l) { loans += (x['principal'] as num?)?.toDouble() ?? 0; }
    for (final x in p) { payments += (x['amount'] as num?)?.toDouble() ?? 0; }
    for (final x in e) { expenses += (x['amount'] as num?)?.toDouble() ?? 0; }
    for (final x in i) { pending += ((x['amount'] as num?)?.toDouble() ?? 0) - ((x['paid_amount'] as num?)?.toDouble() ?? 0); }
    final today=DateTime.now().toIso8601String().substring(0,10);
    final overdue=i.where((x)=>x['status']!='paid' && (x['due_date']?.toString()??'').compareTo(today)<0).fold<double>(0,(a,x)=>a+(((x['amount'] as num?)?.toDouble()??0)-((x['paid_amount'] as num?)?.toDouble()??0)));
    return {'customers':c.length,'loans':loans,'payments':payments,'pending':pending,'overdue':overdue,'activeLoans':l.where((x)=>x['status']=='active').length,'installments':i.length,'expenses':expenses,'balance':payments-expenses};
  }
}

extension CobrAppSettingsRepository on CobrAppRepository {
  Future<Map<String,dynamic>?> profile() async {
    final rows = await db.from('cobrapp_profiles').select().eq('user_id', uid).limit(1);
    if (rows.isEmpty) return null;
    return Map<String,dynamic>.from(rows.first);
  }
  Future<void> saveProfile({required String name, String? phone, String? businessName, String? currency}) async {
    await db.from('cobrapp_profiles').upsert({
      'user_id': uid,
      'name': name,
      'phone': phone,
      'business_name': businessName,
      'currency': currency ?? 'BRL',
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }
}
