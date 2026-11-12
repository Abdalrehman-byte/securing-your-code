import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// UI strings in English and Arabic.
///
/// Only the app's own labels are translated. Everything that comes from a
/// data source (names, field names, values, messages) is shown exactly as
/// returned and is never translated.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  @visibleForTesting
  static Map<String, Map<String, String>> get values => _values;

  String _t(String key) {
    return _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;
  }

  String _n(String key, Map<String, Object> args) {
    var text = _t(key);
    args.forEach((name, value) {
      text = text.replaceAll('{$name}', '$value');
    });
    return text;
  }

  String get appTitle => _t('appTitle');
  String get tabDatabase => _t('tabDatabase');
  String get tabVin => _t('tabVin');
  String get make => _t('make');
  String get model => _t('model');
  String get modelYear => _t('modelYear');
  String get vehicleType => _t('vehicleType');
  String get engineType => _t('engineType');
  String get notAvailable => _t('notAvailable');
  String get selectMake => _t('selectMake');
  String get searchMakes => _t('searchMakes');
  String get yearHelper => _t('yearHelper');
  String get invalidYear => _t('invalidYear');
  String get all => _t('all');
  String get selectMakeFirst => _t('selectMakeFirst');
  String get modelNameFilter => _t('modelNameFilter');
  String get search => _t('search');
  String get engineFilterExplanation => _t('engineFilterExplanation');
  String get decodeVin => _t('decodeVin');
  String results(int n) => _n('results', <String, Object>{'n': n});
  String showingOf(int shown, int total) {
    return _n('showingOf', <String, Object>{'shown': shown, 'total': total});
  }

  String get noResultsFromSource => _t('noResultsFromSource');
  String get noMatchInResults => _t('noMatchInResults');
  String get source => _t('source');
  String get sourceName => _t('sourceName');
  String get fetched => _t('fetched');
  String get originNetwork => _t('originNetwork');
  String get originCache => _t('originCache');
  String get originStale => _t('originStale');
  String get refresh => _t('refresh');
  String get retry => _t('retry');
  String get errorOffline => _t('errorOffline');
  String get errorHttp => _t('errorHttp');
  String get errorBadResponse => _t('errorBadResponse');
  String get recordAsReturned => _t('recordAsReturned');
  String get yourQuery => _t('yourQuery');
  String get anyYear => _t('anyYear');
  String get canadianSpecs => _t('canadianSpecs');
  String get requiresYear => _t('requiresYear');
  String entry(int n) => _n('entry', <String, Object>{'n': n});
  String get engineSpecs => _t('engineSpecs');
  String get vin => _t('vin');
  String get vinHelper => _t('vinHelper');
  String get invalidVin => _t('invalidVin');
  String get decode => _t('decode');
  String get messageFromSource => _t('messageFromSource');
  String get searchCriteria => _t('searchCriteria');
  String get showEmptyFields => _t('showEmptyFields');
  String emptyFieldCount(int n) {
    return _n('emptyFieldCount', <String, Object>{'n': n});
  }

  String get save => _t('save');
  String get saved => _t('saved');
  String get remove => _t('remove');
  String get savedVehicles => _t('savedVehicles');
  String get noSavedVehicles => _t('noSavedVehicles');
  String get engineFilterField => _t('engineFilterField');
  String get details => _t('details');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'en' || locale.languageCode == 'ar';
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const Map<String, Map<String, String>> _values = <String, Map<String, String>>{
  'en': <String, String>{
    'appTitle': 'Car Repair',
    'tabDatabase': 'Car database',
    'tabVin': 'By VIN',
    'make': 'Make',
    'model': 'Model',
    'modelYear': 'Model year',
    'vehicleType': 'Vehicle type',
    'engineType': 'Engine type',
    'notAvailable': 'Not available',
    'selectMake': 'Select a make',
    'searchMakes': 'Search makes',
    'yearHelper':
        'Optional. Sent to the source as a filter; the source has no list of years.',
    'invalidYear': 'Enter a 4-digit year',
    'all': 'All',
    'selectMakeFirst': 'Select a make first',
    'modelNameFilter': 'Filter by model name',
    'search': 'Search',
    'engineFilterExplanation':
        'The source (vPIC) does not return engine data for a make, model and year. Engine fields are returned only when a VIN is decoded.',
    'decodeVin': 'Decode a VIN',
    'results': 'Results: {n}',
    'showingOf': 'Showing {shown} of {total}',
    'noResultsFromSource': 'The source returned no results for this query.',
    'noMatchInResults': 'No returned record matches this text.',
    'source': 'Source',
    'sourceName': 'NHTSA vPIC API (official)',
    'fetched': 'Fetched',
    'originNetwork': 'live from the source',
    'originCache': 'saved copy on this device',
    'originStale': 'offline, showing the saved copy',
    'refresh': 'Refresh from the source',
    'retry': 'Retry',
    'errorOffline':
        'Could not reach the source and there is no saved copy on this device.',
    'errorHttp': 'The source answered with an error.',
    'errorBadResponse': 'The source returned a response that could not be read.',
    'recordAsReturned': 'Record exactly as returned by the source',
    'yourQuery': 'Your query',
    'anyYear': 'Any year',
    'canadianSpecs': 'Canadian Vehicle Specifications (via vPIC)',
    'requiresYear': 'A model year is required to query these specifications.',
    'entry': 'Entry {n}',
    'engineSpecs': 'Engine specifications',
    'vin': 'VIN',
    'vinHelper': 'Up to 17 characters. Use * for unknown characters.',
    'invalidVin': 'Enter a VIN using letters, digits or *',
    'decode': 'Decode',
    'messageFromSource': 'Message from the source',
    'searchCriteria': 'Search criteria reported by the source',
    'showEmptyFields': 'Show fields with no data',
    'emptyFieldCount': 'Fields with no data from the source: {n}',
    'save': 'Save',
    'saved': 'Saved',
    'remove': 'Remove',
    'savedVehicles': 'Saved vehicles',
    'noSavedVehicles': 'No saved vehicles yet. Decode a VIN and save it.',
    'engineFilterField': 'Engine type (source field: FuelTypePrimary)',
    'details': 'Details',
  },
  'ar': <String, String>{
    'appTitle': 'إصلاح السيارات',
    'tabDatabase': 'قاعدة بيانات السيارات',
    'tabVin': 'برقم الهيكل',
    'make': 'الشركة المصنّعة',
    'model': 'الطراز',
    'modelYear': 'سنة الطراز',
    'vehicleType': 'نوع المركبة',
    'engineType': 'نوع المحرك',
    'notAvailable': 'غير متوفر',
    'selectMake': 'اختر الشركة المصنّعة',
    'searchMakes': 'ابحث عن شركة مصنّعة',
    'yearHelper':
        'اختياري. تُرسَل إلى المصدر كعامل تصفية؛ المصدر لا يوفّر قائمة بالسنوات.',
    'invalidYear': 'أدخل سنة من 4 أرقام',
    'all': 'الكل',
    'selectMakeFirst': 'اختر الشركة المصنّعة أولاً',
    'modelNameFilter': 'تصفية حسب اسم الطراز',
    'search': 'بحث',
    'engineFilterExplanation':
        'المصدر (vPIC) لا يُرجِع بيانات المحرك حسب الشركة المصنّعة والطراز والسنة. حقول المحرك تُعاد فقط عند فك ترميز رقم الهيكل (VIN).',
    'decodeVin': 'فك ترميز رقم الهيكل',
    'results': 'النتائج: {n}',
    'showingOf': 'عرض {shown} من {total}',
    'noResultsFromSource': 'لم يُرجِع المصدر أي نتائج لهذا الاستعلام.',
    'noMatchInResults': 'لا يوجد سجل مُعاد يطابق هذا النص.',
    'source': 'المصدر',
    'sourceName': 'واجهة NHTSA vPIC الرسمية',
    'fetched': 'تاريخ الجلب',
    'originNetwork': 'مباشرة من المصدر',
    'originCache': 'نسخة محفوظة على هذا الجهاز',
    'originStale': 'بلا اتصال، تُعرض النسخة المحفوظة',
    'refresh': 'تحديث من المصدر',
    'retry': 'إعادة المحاولة',
    'errorOffline':
        'تعذّر الوصول إلى المصدر ولا توجد نسخة محفوظة على هذا الجهاز.',
    'errorHttp': 'ردّ المصدر بخطأ.',
    'errorBadResponse': 'أعاد المصدر ردًّا تعذّرت قراءته.',
    'recordAsReturned': 'السجل كما أعاده المصدر تمامًا',
    'yourQuery': 'استعلامك',
    'anyYear': 'أي سنة',
    'canadianSpecs': 'مواصفات المركبات الكندية (عبر vPIC)',
    'requiresYear': 'يلزم تحديد سنة الطراز للاستعلام عن هذه المواصفات.',
    'entry': 'السجل {n}',
    'engineSpecs': 'مواصفات المحرك',
    'vin': 'رقم الهيكل (VIN)',
    'vinHelper': 'حتى 17 خانة. استخدم * للخانات غير المعروفة.',
    'invalidVin': 'أدخل رقم هيكل مكوّنًا من أحرف لاتينية أو أرقام أو *',
    'decode': 'فك الترميز',
    'messageFromSource': 'رسالة من المصدر',
    'searchCriteria': 'معايير البحث كما أوردها المصدر',
    'showEmptyFields': 'إظهار الحقول التي لا بيانات لها',
    'emptyFieldCount': 'حقول بلا بيانات من المصدر: {n}',
    'save': 'حفظ',
    'saved': 'تم الحفظ',
    'remove': 'حذف',
    'savedVehicles': 'المركبات المحفوظة',
    'noSavedVehicles': 'لا توجد مركبات محفوظة بعد. فُكّ ترميز رقم هيكل ثم احفظه.',
    'engineFilterField': 'نوع المحرك (حقل المصدر: FuelTypePrimary)',
    'details': 'التفاصيل',
  },
};
