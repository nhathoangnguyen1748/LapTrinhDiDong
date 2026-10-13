import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../common/glass_card.dart';
import '../../common/neumorphic_button.dart';
import 'teacher_exam_list_screen.dart';

class TeacherLoginScreen extends ConsumerStatefulWidget {
  const TeacherLoginScreen({super.key});

  @override
  ConsumerState<TeacherLoginScreen> createState() => _TeacherLoginScreenState();
}

class _TeacherLoginScreenState extends ConsumerState<TeacherLoginScreen> {
  final _emailController = TextEditingController(text: 'teacher@localquiz.edu.vn');
  final _passwordController = TextEditingController(text: '123456');
  final _nameController = TextEditingController(text: 'ThS. Nguyễn Văn Hùng');
  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showToast('Vui lòng điền Email và Mật khẩu', isError: true);
      return;
    }

    if (_isRegisterMode && name.isEmpty) {
      _showToast('Vui lòng nhập Họ và tên', isError: true);
      return;
    }

    bool success;
    if (_isRegisterMode) {
      success = await ref.read(authProvider.notifier).register(email, password, name);
    } else {
      success = await ref.read(authProvider.notifier).login(email, password);
    }

    if (!mounted) return;

    if (success) {
      _showToast(_isRegisterMode ? 'Đăng ký thành công!' : 'Đăng nhập thành công!');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherExamListScreen()),
      );
    } else {
      final error = ref.read(authProvider).error ?? 'Đăng nhập thất bại';
      _showToast(error, isError: true);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.rssiCritical : AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showServerConfigDialog() {
    final urlController = TextEditingController(text: ApiService.instance.baseUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cấu hình Server API', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: urlController,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Địa chỉ Server (FastAPI)',
                hintText: 'http://192.168.1.15:8000/api/v1',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              await ApiService.instance.setBaseUrl(urlController.text);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                _showToast('Đã lưu máy chủ: ${ApiService.instance.baseUrl}');
                setState(() {});
              }
            },
            child: const Text('Lưu', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cổng Giảng Viên'),
        actions: [
          IconButton(
            tooltip: 'Cài đặt IP Server',
            icon: const Icon(Icons.settings_ethernet_rounded),
            onPressed: _showServerConfigDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.emeraldGradient,
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                ),
              ),

              const SizedBox(height: 14),

              Center(
                child: Text(
                  _isRegisterMode ? 'Đăng Ký Giảng Viên' : 'Đăng Nhập Giảng Viên',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Server Indicator
              Center(
                child: InkWell(
                  onTap: _showServerConfigDialog,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_done_rounded, size: 12, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            ApiService.instance.baseUrl,
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Form
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_isRegisterMode) ...[
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Họ và tên Giảng viên',
                          prefixIcon: const Icon(Icons.badge_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 16),

                    NeumorphicButton(
                      gradient: AppColors.emeraldGradient,
                      isLoading: authState.isLoading,
                      onPressed: _handleSubmit,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isRegisterMode ? Icons.person_add_rounded : Icons.login_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isRegisterMode ? 'ĐĂNG KÝ' : 'ĐĂNG NHẬP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  setState(() => _isRegisterMode = !_isRegisterMode);
                },
                child: Text(
                  _isRegisterMode
                      ? 'Đã có tài khoản? Đăng nhập'
                      : 'Chưa có tài khoản? Đăng ký',
                  style: const TextStyle(color: AppColors.primaryLight, fontSize: 12),
                ),
              ),

              const SizedBox(height: 8),

              // Demo fill button
              OutlinedButton.icon(
                icon: const Icon(Icons.flash_on_rounded, color: AppColors.rssiWarning, size: 14),
                label: const Text(
                  'Điền tài khoản Demo',
                  style: TextStyle(fontSize: 11, color: AppColors.rssiWarning),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.rssiWarning.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () {
                  setState(() {
                    _emailController.text = 'teacher@localquiz.edu.vn';
                    _passwordController.text = '123456';
                    _isRegisterMode = false;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
