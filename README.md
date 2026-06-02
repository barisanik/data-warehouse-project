# Veri Ambarı Projesi
(TR 🇹🇷 | English below)

Bu proje; SQL Server üzerinde çalışan, analiz süreçleri için tasarlanmış uçtan uca bir veri ambarı (Data Warehouse) oluşturma sürecini ve buna ait SQL sorgularını içermektedir.

## Veri Kaynağı
Projede kullanılan CSV dosyaları [datasets](https://github.com/barisanik/data-warehouse-project/tree/main/datasets) dizini altında yer almaktadır.
Kullanılan API adresleri:
- [Dummy JSON - Products](https://dummyjson.com/products?limit=1000)
- [Dummy JSON - Users](https://dummyjson.com/user?limit=10000)
- [Dummy JSON - Carts](https://dummyjson.com/carts?limit=10000)
<img width="10112" height="6096" alt="ER Diagram" src="https://github.com/user-attachments/assets/e7c01ed7-526c-4a9f-af03-64470fd8a24e" />



## Proje Kararları
- Veri kaynağı olarak 6 adet CSV dosyası kullanılmaktadır. Veri modelleme aşaması için madalyon mimarisi (bronze-silver-gold) kullanılacaktır.
- İkame edilemeyen tüm NULL değerler 'n/a' olarak düzenlenecektir.
- Doğru olmayan doğum tarihleri (çok eski veya 18 yaşından genç olan) NULL olarak kaydedilecektir.
- Sembol ve kısaltma olarak kullanılan tüm ifadeler anlamlı metinlerle değiştirilecektir.
- Veri yükleme tekniği olarak Full Load tercih edilmiştir. Veri kaynağından veri ambarına tüm veriler tek seferde aktarılacaktır.
- Değişken isimlendirme metodu olarak snake case kullanılacaktır.
- Sorgularda ve kod parçacıklarında yorum satırlarında İngilizce dili kullanılacaktır.
- Dummyjson kaynağından elde edilen sepetteki ürün verileri veri ambarına sipariş olarak işlenecektir.

## Referanslar
Bu proje aşağıdaki kaynağı referans alarak oluşturulmuştur. Temel metodoloji ilgili videoya dayanmakla birlikte farklı veri kaynakları projeye entegre edilerek modelleme süreçleri bu doğrultuda genişletilmiştir.
- [SQL Data Warehouse from Scratch - Data with Baraa](https://youtu.be/9GVqKuTVANE?si=pPUQ8cy8OA3J2cBF)

---

# Data Warehouse Project
(EN 🇬🇧)

This project showcases an end-to-end data warehousing and analytics solution. It includes SQL scripts for building a data warehouse for analytical purposes on SQL Server.

## Data Source
CSV files used in this project can be found under the [datasets](https://github.com/barisanik/data-warehouse-project/tree/main/datasets) directory.
API endpoints used:
- [Dummy JSON - Products](https://dummyjson.com/products?limit=1000)
- [Dummy JSON - Users](https://dummyjson.com/user?limit=10000)
- [Dummy JSON - Carts](https://dummyjson.com/carts?limit=10000)
<img width="10112" height="6096" alt="ER Diagram" src="https://github.com/user-attachments/assets/e7c01ed7-526c-4a9f-af03-64470fd8a24e" />

## Project Decisions
- Six CSV files are used as data sources. The medallion architecture (bronze-silver-gold) will be utilized for the data modeling phase.
- All non-replaceable NULL values will be set to 'n/a'.
- Unrealistic or invalid birth dates (e.g., unrealistically old or under 18) are replaced with NULL
- All symbols and abbreviations will be replaced with meaningful descriptions.
- Full load has been preferred as the data loading technique, meaning the entire dataset from the source files will be transferred to the data warehouse in a single operation.
- Snake case will be used for variable naming.
- English will be used in comments for queries and code snippets.
- Cart data sourced from DummyJSON is processed as orders.

## References
This project was built using the following video resource. Although the foundational methodology relies on the video, the data modeling processes were expanded by integrating diverse data sources.
- [SQL Data Warehouse from Scratch - Data with Baraa](https://youtu.be/9GVqKuTVANE?si=pPUQ8cy8OA3J2cBF)
