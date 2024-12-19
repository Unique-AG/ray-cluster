---
layout: page
title: Ceph
permalink: /ceph/
---

Unique Ray Cluster uses [Ceph](https://docs.ceph.com) for distributed storage. Ceph is a distributed object store and file system designed to provide excellent performance, reliability, and scalability.

### Ceph Implementation Details
When deploying an S3-compatible object-storage with Ceph, it sets the region parameter to `us-east-1` by default. This is done to be compatible with the S3 API that always requires a region.

Ceph strives to be 100% compatible with the [Amazon Simple Storage Service (S3)](https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html) API. Since AWS S3™️ expects that a region is always specified, Ceph mimics this behavior by defaulting the region to `us-east-1`. 

**🟢 It is though to note that no data or anything else from the Ceph implementation ever leaves the cluster, not to mention to `us-east-1`.**