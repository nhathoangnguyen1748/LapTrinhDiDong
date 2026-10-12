import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      _showToast('Vui lòng điền đầy đủ Email và Mật khẩu', isError: true);
      return;
    }

    if (_isRegisterMode && name.isEmpty) {
      _showToast('Vui lòng nhập Họ và tên của Giảng viên', isError: true);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Cấu hình Backend API', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Địa chỉ máy chủ FastAPI (Local LAN hoặc Cloud):',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'http://192.168.1.15:8000/api/v1',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gợi ý:\n• Máy ảo Android: http://10.0.2.2:8000/api/v1\n• Máy thật cùng Wi-Fi: http://<IP_MAY_TINH>:8000/api/v1\n• Desktop Windows: http://localhost:8000/api/v1',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4),
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
                _showToast('Đã cập nhật máy chủ: ${ApiService.instance.baseUrl}');
                setState(() {});
              }
            },
            child: const Text('Lưu máy chủ', style: TextStyle(color: Colors.white)),
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
        title: const Text('Giảng Viên Đăng Nhập'),
        actions: [
          IconButton(
            tooltip: 'Cài đặt IP Máy chủ Backend',
            icon: const Icon(Icons.settings_ethernet_rounded),
            onPressed: _showServerConfigDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // Hero Badge
              Center(
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.emeraldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 36),
                ),
              ).animate().scale(duration: 500.ms).fadeIn(),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  _isRegisterMode ? 'Đăng Ký Tài Khoản Giảng Viên' : 'Cổng Quản Trị Giảng Viên',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              const Center(
                child: Text(
                  'Quản lý ngân hàng đề & Đồng bộ kết quả ca thi với Cloud',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),

              const SizedBox(height: 24),

              // Server Indicator Pill
              GestureDetector(
                onTap: _showServerConfigDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Server: ${ApiService.instance.baseUrl}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded, size: 12, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Form Container
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (_isRegisterMode) ...[
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Họ và tên Giảng viên',
                          prefixIcon: const Icon(Icons.badge_rounded, color: AppColors.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Email Giảng viên',
                        prefixIcon: const Icon(Icons.email_rounded, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 20),

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
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isRegisterMode ? 'ĐĂNG KÝ TÀI KHOẢN' : 'ĐĂNG NHẬP HỆ THỐNG',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Switch Login / Register
              TextButton(
                onPressed: () {
                  setState(() => _isRegisterMode = !_isRegisterMode);
                },
                child: Text(
                  _isRegisterMode
                      ? 'Đã có tài khoản? Đăng nhập ngay'
                      : 'Chưa có tài khoản? Đăng ký Giảng viên mới',
                  style: const TextStyle(color: AppColors.primaryLight, fontSize: 13),
                ),
              ),

              const SizedBox(height: 10),

              // Quick Fill Helper for Demo / Testing
              OutlinedButton.icon(
                icon: const Icon(Icons.flash_on_rounded, color: AppColors.rssiWarning, size: 16),
                label: const Flexible(
                  child: Text(
                    'Điền tài khoản mẫu Demo (1 chạm)',
                    style: TextStyle(fontSize: 11, color: AppColors.rssiWarning),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.rssiWarning.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
