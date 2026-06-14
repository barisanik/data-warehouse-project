# Veri Ambarı Projesi
(TR 🇹🇷 | English below)

Bu proje; SQL Server üzerinde çalışan, analiz süreçleri için tasarlanmış uçtan uca bir veri ambarı (Data Warehouse) oluşturma sürecini ve buna ait SQL sorgularını içermektedir.

## Kullanılan Teknolojiler

| Katman | Teknoloji |
|--------|-----------|
| Veritabanı | SQL Server 2022 (Docker) |
| Veri Çekme | Python ([get_data.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/get_data.py)) |
| Dönüşüm | dbt (Silver + Gold katmanları) |
| Orkestrasyon | Apache Airflow |
| Container | Docker + Docker Compose |
| Raporlama | Metabase |

## Mimari

```
HAM VERİ KAYNAKLARI
  ├── ERP CSV dosyaları (ürün kategorileri ve bakım bilgisi, müşteri detayları (doğum tarihi, cinsiyet, konum))
  └── CRM CSV dosyaları (müşteriler, siparişler, ürünler)
  └── DummyJSON API (müşteriler, siparişler, ürünler)
        │
        ▼
    BRONZE        Ham veriyi tutar, dönüşüm uygulanmaz.
        │         bronze.crm_*, bronze.erp_*, bronze.djapi_*
        ▼
    SILVER        Temizlenmiş, normalize edilmiş, doğrulanmış verileri içerir. 9 dbt staging modeli + veri kalite testlerini içerir
        │         silver.stg_crm__*, silver.stg_erp__*, silver.stg_djapi__* 
        ▼
      GOLD        Görselleştirme aşamasında kullanılan analitik tabloları içerir.
                  3 dbt mart modeli: gold.dim_customer, gold.dim_product, gold.fact_sales
```

## Pipeline Akışı

```
sqlserver → sqlserver-setup → ingestion → dbt run → dbt test
```

## Veri Kaynağı

Projede kullanılan CSV dosyaları [datasets](https://github.com/barisanik/data-warehouse-project/tree/main/datasets) dizini altında yer almaktadır.
Kullanılan API adresleri:
- [Dummy JSON - Products](https://dummyjson.com/products?limit=1000)
- [Dummy JSON - Users](https://dummyjson.com/user?limit=10000)
- [Dummy JSON - Carts](https://dummyjson.com/carts?limit=10000)
<img width="10112" height="6096" alt="ER Diagram" src="https://github.com/user-attachments/assets/e7c01ed7-526c-4a9f-af03-64470fd8a24e" />

## Kurulum
**Gereksinimler:** Docker Desktop

1. Repo'yu klonlayın.
2. Projenin ana dizininde `.env` dosyasını oluşturun:

```env
SA_USERNAME=sa
SA_PASSWORD=<şifre>        # Büyük/küçük harf + rakam + sembol içermeli
SERVER_NAME=sqlserver
DATABASE_NAME=DataWarehouse
DRIVER_NAME=ODBC Driver 18 for SQL Server
AIRFLOW_ADMIN_USERNAME=admin
AIRFLOW_ADMIN_PASSWORD=<şifre>
AIRFLOW_ADMIN_EMAIL=<e-posta>
```
.env dosyası örneği için [.env - Sample](https://github.com/barisanik/data-warehouse-project/blob/main/.env%20-%20Sample) dosyasına göz atabilirsiniz.

3. Docker Compose'u çalıştırın:

```bash
cd docker
docker compose up -d
```

**Arayüz Erişim Adresleri & Veritabanı Erişim Bilgileri:**

- Airflow UI: `http://localhost:8080`
- Metabase UI: `http://localhost:3000`
- SQL Server: 
  - Server Name: `localhost,1435`
  - Authentication: `SQL Server Authentication`
  - User Name: `sa`
  - Password: `.env dosyasında yer alan SA_PASSWORD değeri`

## Proje Kararları

- Mimari
  - Veri modelleme aşaması için madalyon mimarisi (bronze-silver-gold) kullanılacaktır.
  - CSV ve API kaynaklarından gelen kayıtlar UNION ALL ile birleştirildiğinde ID çakışmasını önlemek amacıyla kaynak bazlı prefix stratejisi uygulanmıştır. CSV kaynaklı kayıtlar `CSV-`, API kaynaklı kayıtlar `API-` prefix'i ile işaretlenir.
- Veri çekme
  - Veri çekme aşamasında %40 oranında kasıtlı veri bozulması uygulanır. Bu sayede bozuk veri kalitesi durumları simüle edilir.
  - Veri yükleme tekniği olarak Full Load tercih edilmiştir. Veri kaynağından veri ambarına tüm veriler tek seferde aktarılacaktır.
  - Dummyjson kaynağından elde edilen sepetteki ürün verileri veri ambarına sipariş olarak işlenecektir.
- Dönüşüm
  - İkame edilemeyen tüm NULL değerler 'n/a' olarak düzenlenecektir.
  - Doğru olmayan doğum tarihleri (çok eski veya 18 yaşından genç olan) NULL olarak kaydedilecektir.
  - Sembol ve kısaltma olarak kullanılan tüm ifadeler anlamlı metinlerle değiştirilecektir.
- Sözdizimi
  - Değişken isimlendirme metodu olarak snake case kullanılacaktır.
  - Sorgularda ve kod parçacıklarında yorum satırlarında İngilizce dili kullanılacaktır.
- Kullanılan teknolojiler
  - dbt veri kalite kontrolü, silver ve gold katman tablolarının oluşturulmasında kullanılacaktır. Bronze katman tablolarında ham veri tutulması nedeniyle veri kalite kontrolü uygulanmayacaktır.

## Referanslar
Bu proje aşağıdaki kaynağı referans alarak oluşturulmuştur. Temel metodoloji ilgili videoya dayanmakla birlikte farklı veri kaynakları projeye entegre edilerek modelleme süreçleri bu doğrultuda genişletilmiştir.
- [SQL Data Warehouse from Scratch - Data with Baraa](https://youtu.be/9GVqKuTVANE?si=pPUQ8cy8OA3J2cBF)

---

# Data Warehouse Project
(EN 🇬🇧)

This project showcases an end-to-end data warehousing and analytics solution. It includes SQL scripts for building a data warehouse for analytical purposes on SQL Server.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Database | SQL Server 2022 (Docker) |
| Ingestion | Python ([get_data.py](https://github.com/barisanik/data-warehouse-project/blob/main/scripts/bronze/get_data.py)) |
| Transformation | dbt (Silver + Gold layers) |
| Orchestration | Apache Airflow |
| Containers | Docker + Docker Compose |
| Reporting | Metabase |

## Architecture

```
RAW SOURCES
  ├── ERP CSV files (product categories and maintenance details, customer details (birthdate, gender and location))
  └── CRM CSV files (customers, order details, products)
  └── DummyJSON API (customers, order details, products)
        │
        ▼
    BRONZE        Keeps only raw records. No transformation
        │         bronze.crm_*, bronze.erp_*, bronze.djapi_*
        ▼
    SILVER        Cleaned, normalized and validated records. Includes 9 dbt models and data quality tests.
        │         silver.stg_crm__*, silver.stg_erp__*, silver.stg_djapi__* 
        ▼
      GOLD        Stores analytic tables for visualization.
                  3 dbt mart models: gold.dim_customer, gold.dim_product, gold.fact_sales
```

## Pipeline Flow

```
sqlserver → sqlserver-setup → ingestion → dbt run → dbt test
```

## Data Source

CSV files used in this project can be found under the [datasets](https://github.com/barisanik/data-warehouse-project/tree/main/datasets) directory.
API endpoints used:
- [Dummy JSON - Products](https://dummyjson.com/products?limit=1000)
- [Dummy JSON - Users](https://dummyjson.com/user?limit=10000)
- [Dummy JSON - Carts](https://dummyjson.com/carts?limit=10000)
<img width="10112" height="6096" alt="ER Diagram" src="https://github.com/user-attachments/assets/e7c01ed7-526c-4a9f-af03-64470fd8a24e" />

## Initialization
**Requirements:** Docker Desktop

1. Clone this repo.
2. Create a `.env` file in the project root:

```env
SA_USERNAME=sa
SA_PASSWORD=<password>        # Must contain uppercase + lowercase + digit + symbol
SERVER_NAME=sqlserver
DATABASE_NAME=DataWarehouse
DRIVER_NAME=ODBC Driver 18 for SQL Server
AIRFLOW_ADMIN_USERNAME=admin
AIRFLOW_ADMIN_PASSWORD=<password>
AIRFLOW_ADMIN_EMAIL=<email>
```
Please see [.env - Sample](https://github.com/barisanik/data-warehouse-project/blob/main/.env%20-%20Sample) file for a sample file structure.

3. Run Docker Compose:

```bash
cd docker
docker compose up -d
```

**UI Addresses and SQL Connection Details:**

- Airflow UI: `http://localhost:8080`
- Metabase UI: `http://localhost:3000`
- SQL Server: 
  - Server Name: `localhost,1435`
  - Authentication: `SQL Server Authentication`
  - User Name: `sa`
  - Password: `SA_PASSWORD value from .env file.`

## Project Decisions

- Architecture
  - The medallion architecture (bronze-silver-gold) will be utilized for the data modeling phase.
  - A source-based prefix strategy is applied to prevent ID collisions when combining CSV and API records with UNION ALL. CSV-sourced records are prefixed with `CSV-`, API-sourced records with `API-`.
- Ingestion
  - Approximately 40% of ingested API records are intentionally corrupted to simulate real-world data quality issues.
  - Full load has been preferred as the data loading technique, meaning the entire dataset from the source files will be transferred to the data warehouse in a single operation.
  - Cart data sourced from DummyJSON is processed as orders.
- Transformation
  - All non-replaceable NULL values will be set to 'n/a'.
  - Unrealistic or invalid birth dates (e.g., unrealistically old or under 18) are replaced with NULL
  - All symbols and abbreviations will be replaced with meaningful descriptions.
- Syntax
  - Snake case will be used for variable naming.
  - English will be used in comments for queries and code snippets.
- Tech Stack
  - dbt will be utilized for data quality control, as well as the creation of silver layer tables and gold layer tables. Data quality control will not be applied to bronze layer tables, as they store raw data.

## References

This project was built using the following video resource. Although the foundational methodology relies on the video, the data modeling processes were expanded by integrating diverse data sources.
- [SQL Data Warehouse from Scratch - Data with Baraa](https://youtu.be/9GVqKuTVANE?si=pPUQ8cy8OA3J2cBF)
