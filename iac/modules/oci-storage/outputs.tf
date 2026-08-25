output "bucket_name" {
  value = oci_objectstorage_bucket.artifacts.name
}

output "bucket_namespace" {
  value = oci_objectstorage_bucket.artifacts.namespace
}
