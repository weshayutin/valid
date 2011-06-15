import boto 
ec2conn = boto.connect_ec2() 
from boto.ec2.blockdevicemapping import BlockDeviceType, BlockDeviceMapping 
map = BlockDeviceMapping() 
sdb1 = BlockDeviceType() 
sdc1 = BlockDeviceType() 
sdd1 = BlockDeviceType() 
sde1 = BlockDeviceType() 
sdb1.ephemeral_name = 'ephemeral0' 
sdc1.ephemeral_name = 'ephemeral1' 
sdd1.ephemeral_name = 'ephemeral2' 
sde1.ephemeral_name = 'ephemeral3' 
map['/dev/sdb1'] = sdb1 
map['/dev/sdc1'] = sdc1 
map['/dev/sdd1'] = sdd1 
map['/dev/sde1'] = sde1 
img = ec2conn.get_all_images(image_ids=['ami-f61dfd9f'])[0] 
img.run(key_name='id_bv-keypair', instance_type='c1.xlarge', block_device_map=map) 
