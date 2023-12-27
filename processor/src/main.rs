extern crate imap;
extern crate native_tls;

use std::env;

use aws_config::meta::region::RegionProviderChain;
use aws_sdk_s3::{types::Error, Client};
use imap::Session;
use native_tls::TlsStream;

fn build_imap() -> Session<TlsStream<std::net::TcpStream>> {
    let domain = env::var("IMAP_HOST").unwrap();
    let imap_user = env::var("IMAP_USER").unwrap();
    let imap_pass = env::var("IMAP_PASS").unwrap();

    let tls = native_tls::TlsConnector::builder().build().unwrap();
    let client = imap::connect((domain.clone(), 993), domain.clone(), &tls).unwrap();

    return client.login(imap_user, imap_pass).unwrap();
}

async fn s3_client() -> Client {
    let region_provider = RegionProviderChain::default_provider();
    let config = aws_config::defaults(aws_config::BehaviorVersion::v2023_11_09())
        .region(region_provider)
        .load()
        .await;

    let client = aws_sdk_s3::Client::new(&config);
    return client;
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    let mut imap_session = build_imap();

    imap_session.select("INBOX").unwrap();

    let bucket = env::var("BUCKET_NAME").unwrap();

    let client = s3_client().await;

    let objects = client
        .list_objects_v2()
        .bucket(bucket.clone())
        .prefix("incoming/")
        .send()
        .await
        .unwrap();

    for obj in objects.contents() {
        let key = obj.key().unwrap();

        let full_object = client
            .get_object()
            .bucket(bucket.clone())
            .key(key)
            .send()
            .await
            .unwrap();

        let mail_contents = full_object.body.collect().await.unwrap().to_vec();

        imap_session.append("INBOX", mail_contents).unwrap();

        client
            .delete_object()
            .bucket(bucket.clone())
            .key(key)
            .send()
            .await
            .unwrap();
    }

    imap_session.close().unwrap();

    Ok(())
}
