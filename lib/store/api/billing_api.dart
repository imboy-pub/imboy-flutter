import 'package:imboy/component/ui/app_loading.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

/// 套餐计费周期
abstract class BillingPeriod {
  static const String month = 'month';
  static const String year = 'year';
}

/// 账单状态（后端 billing_logic.hrl：0=待支付 1=已支付 2=已逾期）
abstract class BillingInvoiceStatus {
  static const int unpaid = 0;
  static const int paid = 1;
  static const int overdue = 2;
}

/// 订阅状态（后端 billing_logic.hrl：0=试用 1=生效 2=已过期 3=已取消）
abstract class BillingSubscriptionStatus {
  static const int trial = 0;
  static const int active = 1;
  static const int expired = 2;
  static const int cancelled = 3;
}

/// 订阅套餐模型。
///
/// 字段与后端 billing_handler:plan_list 响应一致（plan_repo ?COLUMNS）：
/// id/code/name/price(分)/billing_period/quota_config/description/status。
class BillingPlan {
  final int id;
  final String code;
  final String name;
  final int price; // 价格（分）
  final String billingPeriod; // month | year
  final Map<String, dynamic> quotaConfig; // 配额（指标键 → 上限，-1=不限）
  final String description;
  final int status; // 1=上架

  const BillingPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.price,
    required this.billingPeriod,
    required this.quotaConfig,
    required this.description,
    required this.status,
  });

  /// 价格（元），保留两位小数展示
  double get priceYuan => price / 100.0;

  bool get isYearly => billingPeriod == BillingPeriod.year;

  factory BillingPlan.fromJson(Map<String, dynamic> json) {
    return BillingPlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      billingPeriod: json['billing_period']?.toString() ?? BillingPeriod.month,
      quotaConfig:
          (json['quota_config'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      description: json['description']?.toString() ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 账单模型（invoice_repo ?COLUMNS 的客户端子集）。
class BillingInvoice {
  final int id;
  final String invoiceNo;
  final int amount; // 金额（分）
  final int status;

  const BillingInvoice({
    required this.id,
    required this.invoiceNo,
    required this.amount,
    required this.status,
  });

  bool get isPaid => status == BillingInvoiceStatus.paid;

  factory BillingInvoice.fromJson(Map<String, dynamic> json) {
    return BillingInvoice(
      id: (json['id'] as num?)?.toInt() ?? 0,
      invoiceNo: json['invoice_no']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: (json['status'] as num?)?.toInt() ?? BillingInvoiceStatus.unpaid,
    );
  }
}

/// 当前订阅模型（subscription_repo ?COLUMNS 的客户端子集）。
class BillingSubscription {
  final int id;
  final int planId;
  final int status;
  final bool autoRenew;

  const BillingSubscription({
    required this.id,
    required this.planId,
    required this.status,
    required this.autoRenew,
  });

  bool get isActive =>
      status == BillingSubscriptionStatus.active ||
      status == BillingSubscriptionStatus.trial;

  factory BillingSubscription.fromJson(Map<String, dynamic> json) {
    return BillingSubscription(
      id: (json['id'] as num?)?.toInt() ?? 0,
      planId: (json['plan_id'] as num?)?.toInt() ?? 0,
      status:
          (json['status'] as num?)?.toInt() ??
          BillingSubscriptionStatus.expired,
      autoRenew: json['auto_renew'] == true,
    );
  }
}

/// 套餐订阅 API。
///
/// 闭环（对应后端 billing_handler）：
/// 套餐列表 plan_list → 订阅 subscribe（只回 subscription_id）→
/// 生成账单 invoice/generate → 账单列表 invoice/list（取 invoice_no）→
/// 支付 invoice/pay → 当前订阅 subscription。
///
/// 注意：subscribe 响应**不含** invoice_no，账单号只能经
/// generate + list 两步取得（后端 generate 只回 invoice_id 整数）。
class BillingApi extends HttpClient {
  /// 套餐列表（上架）。失败返回 null（页面自渲染错误态，不弹 toast）。
  Future<List<BillingPlan>?> fetchPlans() async {
    IMBoyHttpResponse resp = await get(API.billingPlanList);
    if (!resp.ok || resp.payload == null) {
      return null;
    }
    final payload = resp.payload as Map<String, dynamic>;
    final rawList = payload['list'] as List<dynamic>? ?? [];
    return rawList
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => BillingPlan.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 订阅套餐。成功返回 subscription_id，失败返回 null。
  Future<int?> subscribe(int planId) async {
    IMBoyHttpResponse resp = await post(
      API.billingSubscribe,
      // 后端要求 plan_id 为正整数（is_integer 校验），不能传字符串
      data: {'plan_id': planId},
    );
    if (!resp.ok || resp.payload == null) {
      AppLoading.showError(resp.msg);
      return null;
    }
    return (resp.payload['subscription_id'] as num?)?.toInt();
  }

  /// 按订阅当前周期生成账单（幂等，已生成视为成功）。
  Future<bool> generateInvoice(int subscriptionId) async {
    IMBoyHttpResponse resp = await post(
      API.billingInvoiceGenerate,
      data: {'subscription_id': subscriptionId},
    );
    if (!resp.ok) {
      AppLoading.showError(resp.msg);
      return false;
    }
    // {invoice_id} 或 {already_generated:true} 均视为账单已就绪
    return true;
  }

  /// 账单列表（按 id 倒序）。失败返回 null（编排层静默中止）。
  Future<List<BillingInvoice>?> listInvoices(int subscriptionId) async {
    IMBoyHttpResponse resp = await get(
      API.billingInvoiceList,
      queryParameters: {'subscription_id': subscriptionId},
    );
    if (!resp.ok || resp.payload == null) {
      return null;
    }
    final payload = resp.payload as Map<String, dynamic>;
    final rawList = payload['list'] as List<dynamic>? ?? [];
    return rawList
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => BillingInvoice.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 支付账单。
  ///
  /// 返回后端支付结果 Map：`{invoice_no, payment_no, payment_method,
  /// amount, status}`。当前后端信封**不含** `pay_params`（与 wallet
  /// recharge_pay 不同构，网关透传参数在 billing_logic:do_pay_invoice
  /// 被丢弃），mock 网关即时置已付；若后端未来补上 pay_params（alipay
  /// order_str），编排层会自动走第三方唤起，此处不需感知。
  Future<Map<String, dynamic>?> payInvoice(
    String invoiceNo,
    String paymentMethod,
  ) async {
    IMBoyHttpResponse resp = await post(
      API.billingInvoicePay,
      data: {'invoice_no': invoiceNo, 'payment_method': paymentMethod},
    );
    if (!resp.ok) {
      AppLoading.showError(resp.msg);
      return null;
    }
    if (resp.payload is Map) {
      return Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
    }
    return <String, dynamic>{};
  }

  /// 当前生效/试用订阅。无订阅（payload 为空对象）返回 null。
  Future<BillingSubscription?> fetchSubscription() async {
    IMBoyHttpResponse resp = await get(
      API.billingSubscription,
      queryParameters: {'tenant_id': 0},
    );
    if (!resp.ok || resp.payload is! Map) {
      return null;
    }
    final payload = Map<String, dynamic>.from(
      resp.payload as Map<dynamic, dynamic>,
    );
    if (payload.isEmpty) return null;
    return BillingSubscription.fromJson(payload);
  }
}
