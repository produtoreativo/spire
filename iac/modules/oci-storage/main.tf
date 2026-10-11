resource "oci_objectstorage_bucket" "artifacts" {
  compartment_id        = var.compartment_ocid
  namespace             = var.namespace
  name                  = var.bucket_name
  access_type           = "NoPublicAccess"
  versioning            = var.versioning
  object_events_enabled = true
  freeform_tags         = var.tags

  lifecycle {
    prevent_destroy = true
  }
}
