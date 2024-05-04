

### getAppBytes得到应用APP大小 [link](https://developer.android.com/reference/android/app/usage/StorageStats#getAppBytes())
* getAppBytes得到应用程序的大小。这包括 APK 文件、优化的编译器输出和解压的原生库。
* Added in API level 26

### getCacheBytes得到应用程序缓存数据的大小 [link](https://developer.android.com/reference/android/app/usage/StorageStats#getCacheBytes())
* getCacheBytes得到应用程序缓存数据的大小。这包括存储在Context.getCacheDir()和Context.getCodeCacheDir() 下的文件。
* Context#getCacheDir()这包括存储在和下的文件 Context#getCodeCacheDir()。
* 如果主要外部/共享存储托管在此存储设备上，则这包括存储在 Context#getExternalCacheDir().

### getDataBytes [link](https://developer.android.com/reference/android/app/usage/StorageStats#getDataBytes())
* 返回所有数据的大小。Context#getDataDir()这包括存储在、Context#getCacheDir()、 下的文件 Context#getCodeCacheDir()。
* 如果主要外部/共享存储托管在此存储设备上，则这包括存储在 Context#getExternalFilesDir(String)、 Context#getExternalCacheDir()和 下 的文件Context#getExternalMediaDirs()。
  
### 彻底搞懂Android文件存储---内部存储，外部存储以及各种存储路径解惑

打印结果是基于荣耀7的（系统版本6.0）：
* 1、Environment.getDataDirectory() = /data  
  * 这个方法是获取内部存储的根路径
* 2、getFilesDir().getAbsolutePath() = /data/user/0/packname/files 
  * 这个方法是获取某个应用在内部存储中的files路径
* 3、getCacheDir().getAbsolutePath() = /data/user/0/packname/cache 
  * 这个方法是获取某个应用在内部存储中的cache路径
* 4、getDir(“myFile”, MODE_PRIVATE).getAbsolutePath() = /data/user/0/packname/app_myFile 
  * 这个方法是获取某个应用在内部存储中的自定义路径

方法2,3,4的路径中都带有包名，说明他们是属于某个应用

* 5、Environment.getExternalStorageDirectory().getAbsolutePath() = /storage/emulated/0  
  * 这个方法是获取外部存储的根路径
* 6、Environment.getExternalStoragePublicDirectory(“”).getAbsolutePath() = /storage/emulated/0 
  * 这个方法是获取外部存储的根路径
* 7、getExternalFilesDir(“”).getAbsolutePath() = /storage/emulated/0/Android/data/packname/files
  * 这个方法是获取某个应用在外部存储中的files路径
* 8、getExternalCacheDir().getAbsolutePath() = /storage/emulated/0/Android/data/packname/cache
  * 这个方法是获取某个应用在外部存储中的cache路径
 
注意：其中方法7和方法8如果在4.4以前的系统中getExternalFilesDir("")和getExternalCacheDir()将返回null，如果是4.4及以上的系统才会返回上面的结果，也即4.4以前的系统没插SD卡的话，就没有外部存储，它的SD卡就等于外部存储；而4.4及以后的系统外部存储包括两部分，getExternalFilesDir(“”)和getExternalCacheDir()获取的是机身存储的外部存储部分，也即4.4及以后的系统你不插SD卡，它也有外部存储，既然getExternalFilesDir(“”)和getExternalCacheDir()获取的是机身存储的外部存储部分，那么怎么获取SD卡的存储路径呢，还是通过上面提到的getExternalFilesDirs(Environment.MEDIA_MOUNTED)方法来获取了，不知道Android有没有提供相关的API接口来获取SD卡的存储路径，大家可以去查资料。又重复了上面的话，主要是提醒大家要注意不同的Android版本是有差别的，这个最坑了。
    …………………………………………………………………………………………
    Environment.getDownloadCacheDirectory() = /cache
    Environment.getRootDirectory() = /system
这两个方法没什么说的了，每个版本的android系统都一样

原文链接：https://blog.csdn.net/u010937230/article/details/73303034


### 其他文章
* 一篇文章搞懂android存储目录结构 https://zhuanlan.zhihu.com/p/165140637
