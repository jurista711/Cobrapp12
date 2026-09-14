import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/auth_repository.dart';
import 'core/supabase_config.dart';

class DocumentsRepository {
  SupabaseClient get db => supabase;
  String get uid => AuthRepository().effectiveOwnerId;
  Future<List<Map<String,dynamic>>> templates() async => List<Map<String,dynamic>>.from(await db.from('cobrapp_document_templates').select().eq('user_id',uid).order('updated_at',ascending:false));
  Future<List<Map<String,dynamic>>> customers() async => List<Map<String,dynamic>>.from(await db.from('cobrapp_customers').select('id,name,document,address').eq('user_id',uid).order('name'));
  Future<List<Map<String,dynamic>>> loans(String customerId) async => List<Map<String,dynamic>>.from(await db.from('cobrapp_loans').select('id,principal,total_amount,interest_rate,installments,start_date,end_date').eq('user_id',uid).eq('customer_id',customerId).order('created_at',ascending:false));
  Future<void> saveTemplate({String? id,required String title,required String type,required String body}) async { final row={'user_id':uid,'title':title,'document_type':type,'body':body,'updated_at':DateTime.now().toIso8601String()}; if(id==null){await db.from('cobrapp_document_templates').insert(row);}else{await db.from('cobrapp_document_templates').update(row).eq('id',id).eq('user_id',uid);} }
  Future<void> deleteTemplate(String id) async => db.from('cobrapp_document_templates').delete().eq('id',id).eq('user_id',uid);
  Future<void> cloneTemplate(Map<String,dynamic> t) async => saveTemplate(title:'${t['title']} (cópia)',type:t['document_type']?.toString()??'personalizado',body:t['body']?.toString()??'');
  Future<void> saveGenerated({required String? templateId,required String? customerId,required String? loanId,required String title,required String body,String? clientSignature,String? responsibleSignature,String? witnessSignature}) async => db.from('cobrapp_generated_documents').insert({'user_id':uid,'template_id':templateId,'customer_id':customerId,'loan_id':loanId,'title':title,'body':body,'client_signature':clientSignature,'responsible_signature':responsibleSignature,'witness_signature':witnessSignature});
}