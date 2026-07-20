import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/session.repository.dart';
import 'package:uuid/uuid.dart';

/// In-memory [SessionRepository] used for web and tests.
///
/// The device id is still generated and kept alive inside the process so
/// the flow behaves like on mobile, but nothing survives a page reload.
class InMemorySessionRepository implements SessionRepository {
  Session? _session;
  Device? _device;
  PhoneNumber? _phone;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> write(Session session) async {
    _session = session;
    _device = session.device;
  }

  @override
  Future<PhoneNumber?> readPhoneNumber() async => _phone;

  @override
  Future<void> writePhoneNumber(PhoneNumber phone) async {
    _phone = phone;
  }

  @override
  Future<void> clearSessionPreserveDevice() async {
    _session = null;
    _phone = null;
  }

  @override
  Future<void> clear() async {
    _session = null;
    _phone = null;
    _device = null;
  }

  @override
  Future<Device> readOrCreateDevice() async {
    final existing = _device;
    if (existing != null) return existing;
    final created = Device(id: const Uuid().v4());
    _device = created;
    return created;
  }
}
