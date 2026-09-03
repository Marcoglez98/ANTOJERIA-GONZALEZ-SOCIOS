import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'models/partner_task.dart';
import 'services/cloud_repository.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  runApp(const PartnerApp());
}

class PartnerApp extends StatelessWidget {
  const PartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ANTOJERIA GONZALEZ SOCIOS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE85D04),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF8F2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE85D04),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 2,
        ),
      ),
      home: !DefaultFirebaseOptions.isConfigured
          ? const SetupRequiredPage()
          : const AuthGate(),
    );
  }
}

class SetupRequiredPage extends StatelessWidget {
  const SetupRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ANTOJERIA GONZALEZ SOCIOS'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Falta conectar esta app con Firebase. Sigue el archivo GUIA_FIREBASE.md incluido en el proyecto.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return snapshot.data == null
            ? const LoginPage()
            : const PartnerLoader();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message ?? 'No se pudo iniciar sesión.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 38,
                        backgroundColor: Color(0xFFE85D04),
                        foregroundColor: Colors.white,
                        child: Icon(
                          Icons.restaurant,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'ANTOJERIA GONZALEZ',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE85D04),
                        ),
                      ),
                      const Text(
                        'APP PARA SOCIOS',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2A6F97),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo del socio',
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: loading ? null : login,
                          icon: const Icon(Icons.login),
                          label: Text(
                            loading ? 'Entrando...' : 'Entrar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PartnerLoader extends StatefulWidget {
  const PartnerLoader({super.key});

  @override
  State<PartnerLoader> createState() => _PartnerLoaderState();
}

class _PartnerLoaderState extends State<PartnerLoader> {
  PartnerProfile? profile;
  bool loading = true;
  StreamSubscription<RemoteMessage>? foregroundMessages;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final loadedProfile = await CloudRepository.instance.profile();

    if (loadedProfile != null) {
      await CloudRepository.instance.registerNotifications(loadedProfile);
      foregroundMessages = FirebaseMessaging.onMessage.listen((message) {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.mediumImpact();
      });
    }

    if (mounted) {
      setState(() {
        profile = loadedProfile;
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    foregroundMessages?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cuenta sin asignar'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Este usuario existe, pero todavía no está asignado a uno de los 4 socios. Revisa la colección partners en Firebase.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Dashboard(profile: profile!);
  }
}

class Dashboard extends StatefulWidget {
  final PartnerProfile profile;

  const Dashboard({
    super.key,
    required this.profile,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int tab = 0;
  Timer? reminderTimer;
  List<PartnerTask> latestTasks = const [];
  final Map<String, int> lastReminderBucket = <String, int>{};

  @override
  void initState() {
    super.initState();
    reminderTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => checkReminders(),
    );
  }

  @override
  void dispose() {
    reminderTimer?.cancel();
    super.dispose();
  }

  void checkReminders() {
    if (!mounted) return;

    for (final task in latestTasks) {
      if (task.cancelled ||
          task.paid ||
          task.status == 'delivered' ||
          !task.needsAttention) {
        continue;
      }

      final bucket = task.ageMinutes ~/ 5;
      if (lastReminderBucket[task.id] == bucket) {
        continue;
      }

      lastReminderBucket[task.id] = bucket;
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();

      final message = task.status == 'ready'
          ? 'Pedido #${task.orderId} está LISTO y falta confirmar ENTREGADO.'
          : 'Pedido #${task.orderId} lleva ${task.ageMinutes} min. Revisa su preparación.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );

      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'ANTOJERIA GONZALEZ',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              widget.profile.name,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: CloudRepository.instance.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<PartnerTask>>(
        stream: CloudRepository.instance.streamTasks(
          widget.profile.partnerId,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final all = snapshot.data!;
          latestTasks = all;

          final current = all
              .where(
                (task) =>
                    !task.cancelled &&
                    !task.paid &&
                    task.status != 'delivered',
              )
              .toList();

          final history = all
              .where(
                (task) =>
                    task.cancelled ||
                    task.paid ||
                    task.status == 'delivered',
              )
              .toList();

          final today = all.where((task) => task.isToday).toList();

          if (tab == 0) {
            return TasksView(
              tasks: current,
              empty: 'No tienes pedidos pendientes.',
            );
          }

          if (tab == 1) {
            return TasksView(
              tasks: history,
              empty: 'Todavía no hay historial.',
            );
          }

          return StatsView(
            tasks: today,
            partnerName: widget.profile.name,
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() {
            tab = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: 'Preparar',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights),
            label: 'Mis ventas',
          ),
        ],
      ),
    );
  }
}

class TasksView extends StatelessWidget {
  final List<PartnerTask> tasks;
  final String empty;

  const TasksView({
    super.key,
    required this.tasks,
    required this.empty,
  });

  Color statusColor(String status) {
    switch (status) {
      case 'new':
        return const Color(0xFF2A6F97);
      case 'received':
        return const Color(0xFFF4A261);
      case 'preparing':
        return const Color(0xFFE85D04);
      case 'ready':
        return const Color(0xFF2D6A4F);
      case 'delivered':
        return const Color(0xFF006D77);
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String statusLabel(String status) {
    switch (status) {
      case 'new':
        return 'NUEVO';
      case 'received':
        return 'RECIBIDO';
      case 'preparing':
        return 'PREPARANDO';
      case 'ready':
        return 'LISTO';
      case 'delivered':
        return 'ENTREGADO';
      case 'cancelled':
        return 'CANCELADO';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(empty),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskDetail(task: task),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'PEDIDO #${task.orderId}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor(task.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel(task.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (task.customer.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Cliente: ${task.customer}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        Icon(
                          task.needsAttention
                              ? Icons.warning_amber_rounded
                              : Icons.timer_outlined,
                          size: 18,
                          color: task.needsAttention
                              ? Colors.red
                              : Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Tiempo: ${task.ageMinutes} min',
                          style: TextStyle(
                            fontWeight: task.needsAttention
                                ? FontWeight.w900
                                : FontWeight.w500,
                            color: task.needsAttention
                                ? Colors.red
                                : Colors.grey.shade700,
                          ),
                        ),
                        if (task.needsAttention)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'REQUIERE ATENCIÓN',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  ...task.items.take(4).map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            '${item.quantity} × ${item.name}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  if (task.items.length > 4)
                    Text('+ ${task.items.length - 4} líneas más'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Actualización ${task.revision}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const Text(
                        'Toca para ver detalle →',
                        style: TextStyle(
                          color: Color(0xFFE85D04),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class TaskDetail extends StatelessWidget {
  final PartnerTask task;

  const TaskDetail({
    super.key,
    required this.task,
  });

  Future<void> setStatus(
    BuildContext context,
    String status,
  ) async {
    await CloudRepository.instance.setStatus(task, status);

    if (context.mounted) {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido #${task.orderId}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (task.cancelled)
            const Card(
              color: Color(0xFFFFE5E5),
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'ESTE PEDIDO FUE CANCELADO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          if (task.customer.isNotEmpty)
            ListTile(
              leading: const Icon(
                Icons.person,
                color: Color(0xFF2A6F97),
              ),
              title: const Text('Cliente'),
              subtitle: Text(task.customer),
            ),
          ...task.items.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.quantity} × ${item.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (item.promotionName != null)
                      Text(
                        'Promoción: ${item.promotionName}',
                        style: const TextStyle(
                          color: Color(0xFF2D6A4F),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (item.reason.isNotEmpty)
                      Text(
                        'Detalle: ${item.reason}',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                        ),
                      ),
                    Text(
                      'Importe: \$${item.total.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!task.cancelled && !task.paid)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setStatus(context, 'received'),
                  icon: const Icon(Icons.visibility),
                  label: const Text('RECIBIDO'),
                ),
                FilledButton.icon(
                  onPressed: () => setStatus(context, 'preparing'),
                  icon: const Icon(Icons.soup_kitchen),
                  label: const Text('PREPARANDO'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2D6A4F),
                  ),
                  onPressed: () => setStatus(context, 'ready'),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('LISTO'),
                ),
                if (task.status == 'ready')
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF006D77),
                    ),
                    onPressed: () => setStatus(context, 'delivered'),
                    icon: const Icon(Icons.delivery_dining),
                    label: const Text('CONFIRMAR ENTREGADO'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class StatsView extends StatelessWidget {
  final List<PartnerTask> tasks;
  final String partnerName;

  const StatsView({
    super.key,
    required this.tasks,
    required this.partnerName,
  });

  @override
  Widget build(BuildContext context) {
    final paid = tasks
        .where(
          (task) => task.paid && !task.cancelled,
        )
        .toList();

    final sold = paid.fold<double>(
      0,
      (total, task) => total + task.partnerAmount,
    );

    final units = tasks
        .where((task) => !task.cancelled)
        .fold<int>(
          0,
          (total, task) => total + task.units,
        );

    final ready = tasks
        .where(
          (task) =>
              task.status == 'ready' ||
              task.status == 'delivered' ||
              task.paid,
        )
        .length;

    final preparing = tasks
        .where((task) => task.status == 'preparing')
        .length;

    final pending = tasks
        .where(
          (task) =>
              !task.cancelled &&
              !task.paid &&
              (task.status == 'new' || task.status == 'received'),
        )
        .length;

    final byProduct = <String, int>{};

    for (final task in tasks.where((task) => !task.cancelled)) {
      for (final item in task.items) {
        byProduct[item.name] =
            (byProduct[item.name] ?? 0) + item.quantity;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          'Resumen de $partnerName',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Stat(
              'Vendido',
              '\$${sold.toStringAsFixed(2)}',
              Icons.attach_money,
              const Color(0xFF2D6A4F),
            ),
            _Stat(
              'Unidades',
              '$units',
              Icons.inventory_2,
              const Color(0xFF2A6F97),
            ),
            _Stat(
              'Pendientes',
              '$pending',
              Icons.schedule,
              const Color(0xFFF4A261),
            ),
            _Stat(
              'Preparando',
              '$preparing',
              Icons.soup_kitchen,
              const Color(0xFFE85D04),
            ),
            _Stat(
              'Listos',
              '$ready',
              Icons.check_circle,
              const Color(0xFF40916C),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Producción por producto',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        ...byProduct.entries.map(
          (entry) => ListTile(
            leading: const Icon(
              Icons.fastfood,
              color: Color(0xFFE85D04),
            ),
            title: Text(entry.key),
            trailing: Text(
              '${entry.value}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Stat(
    this.label,
    this.value,
    this.icon,
    this.color,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(label),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
