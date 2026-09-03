import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'models/partner_task.dart';
import 'services/cloud_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  runApp(const PartnerApp());
}

class PartnerApp extends StatelessWidget {
  const PartnerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ANTOJERIA GONZALEZ SOCIOS',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE85D04)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFFF8F2),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFE85D04), foregroundColor: Colors.white, centerTitle: true),
          cardTheme: CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 2),
        ),
        home: !DefaultFirebaseOptions.isConfigured ? const SetupRequiredPage() : const AuthGate(),
      );
}

class SetupRequiredPage extends StatelessWidget {
  const SetupRequiredPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ANTOJERIA GONZALEZ SOCIOS')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Falta conectar esta app con Firebase. Sigue el archivo GUIA_FIREBASE.md incluido en el proyecto.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return snap.data == null ? const LoginPage() : const PartnerLoader();
        },
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;
  @override void dispose(){email.dispose();password.dispose();super.dispose();}
  Future<void> login() async {
    setState(() { loading = true; error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: password.text);
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'No se pudo iniciar sesión.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),child: ConstrainedBox(constraints: const BoxConstraints(maxWidth:460),child: Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
      const CircleAvatar(radius:38,backgroundColor:Color(0xFFE85D04),foregroundColor:Colors.white,child:Icon(Icons.restaurant,size:42)),
      const SizedBox(height:14),
      const Text('ANTOJERIA GONZALEZ',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:Color(0xFFE85D04))),
      const Text('APP PARA SOCIOS',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold,color:Color(0xFF2A6F97))),
      const SizedBox(height:20),
      TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Correo del socio',prefixIcon:Icon(Icons.email))),
      const SizedBox(height:12),
      TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'Contraseña',prefixIcon:Icon(Icons.lock))),
      if(error!=null) Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,style:const TextStyle(color:Colors.red))),
      const SizedBox(height:18),
      SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:loading?null:login,icon:const Icon(Icons.login),label:Text(loading?'Entrando...':'Entrar'))),
    ]))))))),
  );
}

class PartnerLoader extends StatefulWidget {
  const PartnerLoader({super.key});
  @override State<PartnerLoader> createState()=>_PartnerLoaderState();
}
class _PartnerLoaderState extends State<PartnerLoader>{
  PartnerProfile? profile; bool loading=true;
  @override void initState(){super.initState();load();}
  Future<void> load() async {
    final p=await CloudRepository.instance.profile();
    if(p!=null){await CloudRepository.instance.registerNotifications(p);FirebaseMessaging.onMessage.listen((_) {SystemSound.play(SystemSoundType.alert);HapticFeedback.mediumImpact();});}
    if(mounted)setState((){profile=p;loading=false;});
  }
  @override Widget build(BuildContext context){
    if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(profile==null)return Scaffold(appBar:AppBar(title:const Text('Cuenta sin asignar')),body:const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Este usuario existe, pero todavía no está asignado a uno de los 4 socios. Revisa la colección partners en Firebase.',textAlign:TextAlign.center))));
    return Dashboard(profile:profile!);
  }
}

class Dashboard extends StatefulWidget {
  final PartnerProfile profile;
  const Dashboard({super.key,required this.profile});
  @override State<Dashboard> createState()=>_DashboardState();
}
class _DashboardState extends State<Dashboard>{
  int tab=0;
  Timer? _reminderTimer;
  List<PartnerTask> _latestTasks = const [];
  final Map<String,int> _lastReminderBucket = {};

  @override
  void initState(){
    super.initState();
    _reminderTimer=Timer.periodic(const Duration(minutes:1),(_)=>_checkReminders());
  }

  @override
  void dispose(){
    _reminderTimer?.cancel();
    super.dispose();
  }

  void _checkReminders(){
    if(!mounted) return;
    for(final t in _latestTasks){
      if(t.cancelled||t.paid||t.status=='delivered'||!t.needsAttention) continue;
      final bucket=t.ageMinutes~/5;
      if(_lastReminderBucket[t.id]==bucket) continue;
      _lastReminderBucket[t.id]=bucket;
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
      final msg=t.status=='ready'
          ? 'Pedido #${t.orderId} está LISTO y falta confirmar ENTREGADO.'
          : 'Pedido #${t.orderId} lleva ${t.ageMinutes} min. Revisa su preparación.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg),backgroundColor:Colors.red,duration:const Duration(seconds:5)));
      break;
    }
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Column(children:[const Text('ANTOJERIA GONZALEZ',style:TextStyle(fontWeight:FontWeight.w900)),Text(widget.profile.name,style:const TextStyle(fontSize:13))]),actions:[IconButton(onPressed:CloudRepository.instance.signOut,icon:const Icon(Icons.logout))]),
    body:StreamBuilder<List<PartnerTask>>(stream:CloudRepository.instance.streamTasks(widget.profile.partnerId),builder:(context,snap){
      if(!snap.hasData)return const Center(child:CircularProgressIndicator());
      final all=snap.data!;
      _latestTasks = all;
      final current=all.where((t)=>!t.cancelled && !t.paid && t.status!='delivered').toList();
      final history=all.where((t)=>t.cancelled||t.paid||t.status=='delivered').toList();
      final today=all.where((t)=>t.isToday).toList();
      if(tab==0)return TasksView(tasks:current,empty:'No tienes pedidos pendientes.');
      if(tab==1)return TasksView(tasks:history,empty:'Todavía no hay historial.');
      return StatsView(tasks:today,partnerName:widget.profile.name);
    }),
    bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
      NavigationDestination(icon:Icon(Icons.restaurant_menu),label:'Preparar'),
      NavigationDestination(icon:Icon(Icons.history),label:'Historial'),
      NavigationDestination(icon:Icon(Icons.insights),label:'Mis ventas'),
    ]),
  );
}

class TasksView extends StatelessWidget{
  final List<PartnerTask> tasks; final String empty;
  const TasksView({super.key,required this.tasks,required this.empty});
  Color color(String s)=>switch(s){'new'=>const Color(0xFF2A6F97),'received'=>const Color(0xFFF4A261),'preparing'=>const Color(0xFFE85D04),'ready'=>const Color(0xFF2D6A4F),'delivered'=>const Color(0xFF006D77),'cancelled'=>Colors.red,_=>Colors.grey};
  String label(String s)=>switch(s){'new'=>'NUEVO','received'=>'RECIBIDO','preparing'=>'PREPARANDO','ready'=>'LISTO','delivered'=>'ENTREGADO','cancelled'=>'CANCELADO',_=>s.toUpperCase()};
  @override Widget build(BuildContext context){if(tasks.isEmpty)return Center(child:Text(empty));return ListView.builder(padding:const EdgeInsets.all(12),itemCount:tasks.length,itemBuilder:(context,i){final t=tasks[i];return Card(child:InkWell(borderRadius:BorderRadius.circular(18),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>TaskDetail(task:t))),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text('PEDIDO #${t.orderId}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900))),Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:color(t.status),borderRadius:BorderRadius.circular(20)),child:Text(label(t.status),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)))]),
    if(t.customer.isNotEmpty)Padding(padding:const EdgeInsets.only(top:4),child:Text('Cliente: ${t.customer}',style:const TextStyle(fontWeight:FontWeight.w600))),
    Padding(padding:const EdgeInsets.only(top:5),child:Row(children:[Icon(t.needsAttention?Icons.warning_amber_rounded:Icons.timer_outlined,size:18,color:t.needsAttention?Colors.red:Colors.grey),const SizedBox(width:5),Text('Tiempo: ${t.ageMinutes} min',style:TextStyle(fontWeight:t.needsAttention?FontWeight.w900:FontWeight.w500,color:t.needsAttention?Colors.red:Colors.grey.shade700)),if(t.needsAttention)const Padding(padding:EdgeInsets.only(left:8),child:Text('REQUIERE ATENCIÓN',style:TextStyle(color:Colors.red,fontWeight:FontWeight.w900))) ])),
    const Divider(),
    ...t.items.take(4).map((x)=>Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Text('${x.quantity} × ${x.name}',style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600)))),
    if(t.items.length>4)Text('+ ${t.items.length-4} líneas más'),
    const SizedBox(height:8),
    Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('Actualización ${t.revision}',style:const TextStyle(color:Colors.grey)),const Text('Toca para ver detalle →',style:TextStyle(color:Color(0xFFE85D04),fontWeight:FontWeight.bold))]),
  ])))));});}
}

class TaskDetail extends StatelessWidget{
  final PartnerTask task; const TaskDetail({super.key,required this.task});
  Future<void> set(BuildContext c,String s) async {await CloudRepository.instance.setStatus(task,s);if(c.mounted){SystemSound.play(SystemSoundType.click);HapticFeedback.mediumImpact();Navigator.pop(c);}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('Pedido #${task.orderId}')),body:ListView(padding:const EdgeInsets.all(14),children:[
    if(task.cancelled)const Card(color:Color(0xFFFFE5E5),child:Padding(padding:EdgeInsets.all(14),child:Text('ESTE PEDIDO FUE CANCELADO',textAlign:TextAlign.center,style:TextStyle(color:Colors.red,fontWeight:FontWeight.w900,fontSize:18)))),
    if(task.customer.isNotEmpty)ListTile(leading:const Icon(Icons.person,color:Color(0xFF2A6F97)),title:const Text('Cliente'),subtitle:Text(task.customer)),
    ...task.items.map((x)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${x.quantity} × ${x.name}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),if(x.promotionName!=null)Text('Promoción: ${x.promotionName}',style:const TextStyle(color:Color(0xFF2D6A4F),fontWeight:FontWeight.bold)),if(x.reason.isNotEmpty)Text('Detalle: ${x.reason}',style:const TextStyle(color:Colors.deepOrange)),Text('Importe: \$${x.total.toStringAsFixed(2)}')]))),
    const SizedBox(height:10),
    if(!task.cancelled&&!task.paid)Wrap(spacing:8,runSpacing:8,children:[
      OutlinedButton.icon(onPressed:()=>set(context,'received'),icon:const Icon(Icons.visibility),label:const Text('RECIBIDO')),
      FilledButton.icon(onPressed:()=>set(context,'preparing'),icon:const Icon(Icons.soup_kitchen),label:const Text('PREPARANDO')),
      FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:const Color(0xFF2D6A4F)),onPressed:()=>set(context,'ready'),icon:const Icon(Icons.check_circle),label:const Text('LISTO')),
      if(task.status=='ready') FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:const Color(0xFF006D77)),onPressed:()=>set(context,'delivered'),icon:const Icon(Icons.delivery_dining),label:const Text('CONFIRMAR ENTREGADO')),
    ]),
  ]));
}

class StatsView extends StatelessWidget{
  final List<PartnerTask> tasks; final String partnerName;
  const StatsView({super.key,required this.tasks,required this.partnerName});
  @override Widget build(BuildContext context){
    final paid=tasks.where((t)=>t.paid&&!t.cancelled).toList();
    final sold=paid.fold<double>(0,(s,t)=>s+t.partnerAmount);
    final units=tasks.where((t)=>!t.cancelled).fold<int>(0,(s,t)=>s+t.units);
    final ready=tasks.where((t)=>t.status=='ready'||t.status=='delivered'||t.paid).length;
    final preparing=tasks.where((t)=>t.status=='preparing').length;
    final pending=tasks.where((t)=>!t.cancelled&&!t.paid&&(t.status=='new'||t.status=='received')).length;
    final byProduct=<String,int>{};for(final t in tasks.where((t)=>!t.cancelled)){for(final i in t.items){byProduct[i.name]=(byProduct[i.name]??0)+i.quantity;}}
    return ListView(padding:const EdgeInsets.all(14),children:[
      Text('Resumen de $partnerName',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:10),
      Wrap(spacing:10,runSpacing:10,children:[_Stat('Vendido','\$${sold.toStringAsFixed(2)}',Icons.attach_money,const Color(0xFF2D6A4F)),_Stat('Unidades','$units',Icons.inventory_2,const Color(0xFF2A6F97)),_Stat('Pendientes','$pending',Icons.schedule,const Color(0xFFF4A261)),_Stat('Preparando','$preparing',Icons.soup_kitchen,const Color(0xFFE85D04)),_Stat('Listos','$ready',Icons.check_circle,const Color(0xFF40916C))]),
      const SizedBox(height:18),const Text('Producción por producto',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
      ...byProduct.entries.map((e)=>ListTile(leading:const Icon(Icons.fastfood,color:Color(0xFFE85D04)),title:Text(e.key),trailing:Text('${e.value}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)))),
    ]);
  }
}
class _Stat extends StatelessWidget{final String a,b;final IconData icon;final Color color;const _Stat(this.a,this.b,this.icon,this.color);@override Widget build(BuildContext c)=>SizedBox(width:155,child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:color),const SizedBox(height:8),Text(a),Text(b,style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:color))]))));}
