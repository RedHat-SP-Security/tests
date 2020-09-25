
#include <iostream>
#include <fstream>
#include <string.h>
#include <string>
#include <vector>
#include <lmdb.h>


int main(int argc, char *argv[])
{
    MDB_txn *lt_txn;
    MDB_cursor *lt_cursor;
    MDB_dbi dbi;
    MDB_env *env;
    MDB_val key, value;

    char buffer [4096];

    memset(buffer, 0, 4096);

    int rc;

    if (argc < 3) return EXIT_FAILURE;
    std::string data_dir = argv[1];
    std::string file = argv[2];

    mdb_env_create(&env);
    mdb_env_set_maxreaders(env, 4);
    mdb_env_set_maxdbs(env, 2);
    mdb_env_set_mapsize(env, 1024 * 1024 * 1024);

    if (mdb_env_open(env, data_dir.c_str(), MDB_MAPASYNC | MDB_NOSYNC, 0664)) {
      return EXIT_FAILURE;
    }

    if (mdb_txn_begin(env, NULL, 0, &lt_txn)) {
      return EXIT_FAILURE;
    }

    if (mdb_dbi_open(lt_txn, "trust.db", MDB_CREATE, &dbi)) {
      return EXIT_FAILURE;
    }


    if (mdb_cursor_open(lt_txn, dbi, &lt_cursor)) {
      return EXIT_FAILURE;
    }

    key.mv_data = (char *) (file.c_str());
    key.mv_size = file.length();

    value.mv_data = NULL;
    value.mv_size = 0;

    if ((rc = mdb_cursor_get(lt_cursor, &key, &value, MDB_SET_KEY))) {
      if (rc == MDB_NOTFOUND) return EXIT_FAILURE;
    }

    memcpy(buffer, value.mv_data, value.mv_size);

    std::cout << "old: " << buffer << std::endl;

    buffer[value.mv_size-1]++;
    value.mv_data = buffer;
    std::cout << "new: " << buffer << std::endl;

    if ((rc = mdb_cursor_put(lt_cursor, &key, &value, 0))) {
      return EXIT_FAILURE;
    }
    mdb_txn_commit(lt_txn);

    mdb_dbi_close(env, dbi);
    mdb_env_close(env);

    return EXIT_SUCCESS;
}
