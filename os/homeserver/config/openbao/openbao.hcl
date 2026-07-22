ui            = true
disable_mlock = true
api_addr      = "http://openbao:8200"
cluster_addr  = "http://openbao:8201"

storage "raft" {
  path    = "/openbao/data"
  node_id = "openbao"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}
