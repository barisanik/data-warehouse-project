# Veri Ambarı Projesi
(TR 🇹🇷 | English below)

Bu proje; SQL Server üzerinde çalışan, analiz süreçleri için tasarlanmış uçtan uca bir veri ambarı (Data Warehouse) oluşturma sürecini ve buna ait SQL sorgularını içermektedir.

## Veri Kaynağı
Projede kullanılan CSV dosyaları [datasets](https://github.com/barisanik/data-warehouse-project/tree/main/datasets) dizini altında yer almaktadır.
<img width="9988" height="3941" alt="ER Diagram" src="https://github.com/user-attachments/assets/b5858a54-cb43-4f7f-b752-d2af1267713e" />


## Proje Kararları
- Veri kaynağı olarak 6 adet CSV dosyası kullanılmaktadır. Veri modelleme aşaması için madalyon mimarisi (bronze-silver-gold) kullanılacaktır.
- İkame edilemeyen tüm NULL değerler 'n/a' olarak düzenlenecektir.
- Doğru olmayan doğum tarihleri (çok eski veya 18 yaşından genç olan) NULL olarak kaydedilecektir.
- Sembol ve kısaltma olarak kullanılan tüm ifadeler anlamlı metinlerle değiştirilecektir.
- Veri yükleme tekniği olarak Full Load tercih edilmiştir. Veri kaynağından veri ambarına tüm veriler tek seferde aktarılacaktır.

## Referanslar
Bu proje aşağıdaki kaynağı referans alarak oluşturulmuştur:
- [SQL Data Warehouse from Scratch - Data with Baraa](https://youtu.be/9GVqKuTVANE?si=pPUQ8cy8OA3J2cBF)

---

# Data Warehouse Project
(EN 🇬🇧)

This project showcases an end-to-end data warehousing and analytics solution. It includes SQL scripts for building a data warehouse for analytical purposes on SQL Server.

## Data Source
CSV files used in this project can be found under the [datasets](https://github.com/barisanik/data-warehouse-project/tree/main/datasets) directory.
<img width="9988" height="3941" alt="ER Diagram" src="https://github.com/user-attachments/assets/b5858a54-cb43-4f7f-b752-d2af1267713e" />

## Project Decisions
- Six CSV files are used as data sources. The medallion architecture (bronze-silver-gold) will be utilized for the data modeling phase.
- All non-replaceable NULL values will be set to 'n/a'.
- Inaccurate birthday dates will be replaced with NULL.
- All symbols and abbreviations will be replaced with meaningful descriptions.
- Full load has been preferred as the data loading technique, meaning the entire dataset from the source files will be transferred to the data warehouse in a single operation

## References
This project was built using the following video resource:
- [SQL Data Warehouse from Scratch - Data with Baraa](https://youtu.be/9GVqKuTVANE?si=pPUQ8cy8OA3J2cBF)
